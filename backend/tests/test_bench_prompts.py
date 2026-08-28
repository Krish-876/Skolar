"""Unit tests for bench/prompts.py -- prompt formatting and prediction parsing."""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from bench.prompts import build_prompt, format_example, parse_prediction  # noqa: E402

SST2_LABELS = {0: "negative", 1: "positive"}
RTE_LABELS = {0: "entailment", 1: "not entailment"}
TREC_LABELS = {"location": "location", "human": "human", "numeric": "numeric"}


# ── build_prompt ───────────────────────────────────────────────────────────────

def test_build_prompt_zero_shot_has_no_examples_section():
    query = {"sentence": "a fine film"}
    prompt = build_prompt("sst2", query, [], SST2_LABELS)

    assert "Examples:" not in prompt
    assert "a fine film" in prompt
    assert prompt.rstrip().endswith("Label:")


def test_build_prompt_few_shot_includes_all_examples():
    query = {"sentence": "query text"}
    examples = [
        {"sentence": "positive example", "label": 1},
        {"sentence": "negative example", "label": 0},
    ]
    prompt = build_prompt("sst2", query, examples, SST2_LABELS)

    assert "Examples:" in prompt
    assert "positive example" in prompt
    assert "negative example" in prompt
    assert "Label: positive" in prompt
    assert "Label: negative" in prompt
    assert "query text" in prompt


def test_build_prompt_identical_instruction_across_settings():
    # Only the examples should differ between settings -- the instruction and
    # query wording must be byte-identical.
    query = {"sentence": "same query"}
    examples = [{"sentence": "ex", "label": 1}]

    zero_shot_prompt = build_prompt("sst2", query, [], SST2_LABELS)
    few_shot_prompt = build_prompt("sst2", query, examples, SST2_LABELS)

    instruction = zero_shot_prompt.split("\n\n")[0]
    assert few_shot_prompt.startswith(instruction)


def test_build_prompt_rte_shows_premise_and_hypothesis_separately():
    query = {"sentence1": "P text", "sentence2": "H text"}
    prompt = build_prompt("rte", query, [], RTE_LABELS)

    assert "Premise: P text" in prompt
    assert "Hypothesis: H text" in prompt


def test_build_prompt_trec_instruction_lists_derived_categories():
    query = {"text": "What is it?"}
    prompt = build_prompt("trec", query, [], TREC_LABELS)

    assert "'human'" in prompt
    assert "'location'" in prompt
    assert "'numeric'" in prompt


# ── format_example ─────────────────────────────────────────────────────────────

def test_format_example_includes_text_and_gold_label():
    example = {"sentence": "the plot dragged", "label": 0}
    formatted = format_example("sst2", example, SST2_LABELS)

    assert "the plot dragged" in formatted
    assert formatted.endswith("Label: negative")


# ── parse_prediction ────────────────────────────────────────────────────────────

def test_parse_prediction_exact_match():
    assert parse_prediction("positive", SST2_LABELS) == "positive"
    assert parse_prediction("Negative.", SST2_LABELS) == "negative"


def test_parse_prediction_disambiguates_entailment_vs_not_entailment():
    assert parse_prediction("not entailment", RTE_LABELS) == "not entailment"
    assert parse_prediction("entailment", RTE_LABELS) == "entailment"
    assert parse_prediction("The answer is not entailment.", RTE_LABELS) == "not entailment"


def test_parse_prediction_handles_surrounding_text():
    assert parse_prediction("Label: positive", SST2_LABELS) == "positive"


def test_parse_prediction_returns_none_on_no_match():
    assert parse_prediction("I cannot decide", SST2_LABELS) is None


def test_parse_prediction_case_insensitive():
    assert parse_prediction("POSITIVE", SST2_LABELS) == "positive"
