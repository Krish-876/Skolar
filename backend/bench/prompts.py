"""
Per-dataset prompt construction for the bench/ harness.

One builder per dataset lives here so instruction wording is identical across
all three settings (zero_shot/few_shot/mmr_few_shot) for a given dataset --
only the retrieved examples differ. parse_prediction lives alongside the
builders because it has to agree with exactly the label wording the
instruction asked for.
"""

# ── Per-dataset input formatting (for the prompt text, not for embedding --
# embedding uses datasets.extract_text, matching Diverse-ICL's retrieval input) ──

def _format_input_sst2(sample: dict) -> str:
    return sample["sentence"].strip()


def _format_input_cola(sample: dict) -> str:
    return sample["sentence"].strip()


def _format_input_rte(sample: dict) -> str:
    return f"Premise: {sample['sentence1'].strip()}\nHypothesis: {sample['sentence2'].strip()}"


def _format_input_trec(sample: dict) -> str:
    return sample["text"].strip()


_INPUT_FORMATTERS = {
    "sst2": _format_input_sst2,
    "cola": _format_input_cola,
    "rte": _format_input_rte,
    "trec": _format_input_trec,
}

_FIXED_INSTRUCTIONS = {
    "sst2": (
        "Classify the sentiment of the sentence as either 'positive' or 'negative'. "
        "Respond with only the label, nothing else."
    ),
    "cola": (
        "Judge whether the sentence is grammatically 'acceptable' or 'unacceptable' "
        "as English. Respond with only the label, nothing else."
    ),
    "rte": (
        "Given a premise and a hypothesis, decide whether the hypothesis is an "
        "'entailment' or 'not entailment' of the premise. Respond with only the "
        "label, nothing else."
    ),
}


def _instruction_for(dataset: str, label_map_: dict) -> str:
    dataset = dataset.lower()
    if dataset in _FIXED_INSTRUCTIONS:
        return _FIXED_INSTRUCTIONS[dataset]
    if dataset == "trec":
        categories = ", ".join(f"'{c}'" for c in sorted(set(label_map_.values())))
        return (
            f"Classify the question into exactly one of these categories: {categories}. "
            "Respond with only the category name, nothing else."
        )
    raise ValueError(f"Unknown dataset {dataset!r}.")


def format_example(dataset: str, sample: dict, label_map_: dict) -> str:
    dataset = dataset.lower()
    text = _INPUT_FORMATTERS[dataset](sample)
    gold = label_map_[sample["label"]]
    return f"{text}\nLabel: {gold}"


def build_prompt(
    dataset: str,
    query_sample: dict,
    examples: list[dict],
    label_map_: dict,
) -> str:
    """
    Builds the full prompt: instruction, then formatted examples (if any),
    then the query. Identical wording is used regardless of setting -- only
    `examples` (possibly empty, for zero_shot) differs between settings.
    """
    dataset = dataset.lower()
    parts = [_instruction_for(dataset, label_map_)]

    if examples:
        parts.append(
            "Examples:\n\n"
            + "\n\n".join(format_example(dataset, ex, label_map_) for ex in examples)
        )

    parts.append(f"{_INPUT_FORMATTERS[dataset](query_sample)}\nLabel:")
    return "\n\n".join(parts)


def parse_prediction(raw_completion: str, label_map_: dict) -> str | None:
    """
    Maps a raw model completion back to one of the label strings in
    label_map_'s values, or None on parse failure. Longer labels are checked
    first so e.g. 'not entailment' isn't mistaken for a match on 'entailment'.
    """
    labels = sorted(set(label_map_.values()), key=len, reverse=True)
    normalized = raw_completion.strip().strip(".").strip().lower()

    for label in labels:
        if normalized == label.lower():
            return label
    for label in labels:
        if normalized.startswith(label.lower()):
            return label
    for label in labels:
        if label.lower() in normalized:
            return label
    return None
