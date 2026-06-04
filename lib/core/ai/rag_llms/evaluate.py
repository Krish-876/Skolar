"""
Skolar AI — Pipeline Evaluation Script
Run with:
    python evaluate.py

Tests:
    1. MCQ Accuracy     — checks correct_index is valid (0-3), options are distinct
    2. MCQ Diversity    — pairwise cosine similarity across generated questions
    3. Open-ended Quality — checks questions are non-empty, model answers are substantive
    4. Open-ended Diversity — pairwise cosine similarity across generated questions
"""

import requests
import numpy as np
from numpy.linalg import norm
from itertools import combinations

BASE_URL = "http://localhost:8000"
COLLEGE  = "BPHC"
SUBJECT  = "Artificial Intelligence"
MCQ_COUNT  = 10
OPEN_COUNT = 5

# ── Helpers ───────────────────────────────────────────────────────────────────

def cosine_sim(a, b):
    return float(np.dot(a, b) / (norm(a) * norm(b) + 1e-9))

def embed_texts(texts: list[str]) -> np.ndarray:
    """Use sentence-transformers locally to embed texts for diversity scoring."""
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    return model.encode(texts)

def pairwise_similarity(texts: list[str]) -> dict:
    """Return avg, min, max cosine similarity across all pairs."""
    embeddings = embed_texts(texts)
    pairs = list(combinations(range(len(embeddings)), 2))
    if not pairs:
        return {"avg": 0.0, "min": 0.0, "max": 0.0}
    scores = [cosine_sim(embeddings[i], embeddings[j]) for i, j in pairs]
    return {
        "avg": round(float(np.mean(scores)), 3),
        "min": round(float(np.min(scores)), 3),
        "max": round(float(np.max(scores)), 3),
    }

def print_section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_result(label: str, passed: bool, detail: str = ""):
    icon = "✅" if passed else "❌"
    print(f"  {icon}  {label}", end="")
    if detail:
        print(f"  →  {detail}", end="")
    print()

# ── Test 1: Health check ──────────────────────────────────────────────────────

def test_health():
    print_section("HEALTH CHECK")
    r = requests.get(f"{BASE_URL}/health")
    ok = r.status_code == 200 and r.json().get("status") == "ok"
    print_result("Server is up", ok, r.json().get("status", "failed"))
    return ok

# ── Test 2: Stats ─────────────────────────────────────────────────────────────

def test_stats():
    print_section("QUESTION BANK STATS")
    r = requests.get(f"{BASE_URL}/stats", params={"college": COLLEGE})
    data = r.json()
    total = data.get("total_questions", 0)
    print_result("Bank has questions", total > 0, f"{total} questions")
    print_result("Has subjects", len(data.get("subjects", {})) > 0,
                 str(list(data["subjects"].keys())))
    print_result("Has paper years", len(data.get("paper_years", [])) > 0,
                 str(data.get("paper_years", [])))
    return total > 0

# ── Test 3: MCQ Accuracy ──────────────────────────────────────────────────────

def test_mcq_accuracy():
    print_section(f"MCQ ACCURACY  (n={MCQ_COUNT})")
    r = requests.post(f"{BASE_URL}/generate-batch", json={
        "subject": SUBJECT,
        "college": COLLEGE,
        "count":   MCQ_COUNT,
        "exam_type": "midsem",
        "k": 5,
    })

    if r.status_code != 200:
        print(f"  ❌  Request failed: {r.status_code} {r.text}")
        return False

    questions = r.json().get("questions", [])
    generated = len(questions)
    print_result("All requested generated",
                 generated == MCQ_COUNT,
                 f"{generated}/{MCQ_COUNT}")

    valid_index   = 0
    distinct_opts = 0
    non_empty_q   = 0
    for q in questions:
        if 0 <= q.get("correct_index", -1) <= 3:
            valid_index += 1
        opts = q.get("options", [])
        if len(set(opts)) == 4:
            distinct_opts += 1
        if q.get("question", "").strip():
            non_empty_q += 1

    print_result("Valid correct_index (0-3)",
                 valid_index == generated,
                 f"{valid_index}/{generated}")
    print_result("All 4 options distinct",
                 distinct_opts == generated,
                 f"{distinct_opts}/{generated}")
    print_result("Non-empty question text",
                 non_empty_q == generated,
                 f"{non_empty_q}/{generated}")

    # Print questions for manual review
    print("\n  --- Questions for manual review ---")
    for i, q in enumerate(questions, 1):
        print(f"\n  Q{i}: {q['question']}")
        for j, opt in enumerate(q['options']):
            marker = "◀" if j == q['correct_index'] else " "
            print(f"       {chr(65+j)}) {opt} {marker}")

    return valid_index == generated

# ── Test 4: MCQ Diversity ─────────────────────────────────────────────────────

def test_mcq_diversity():
    print_section(f"MCQ DIVERSITY  (n={MCQ_COUNT})")
    r = requests.post(f"{BASE_URL}/generate-batch", json={
        "subject": SUBJECT,
        "college": COLLEGE,
        "count":   MCQ_COUNT,
        "exam_type": "midsem",
        "k": 5,
    })

    if r.status_code != 200:
        print(f"  ❌  Request failed")
        return False

    questions = r.json().get("questions", [])
    texts = [q["question"] for q in questions]

    if len(texts) < 2:
        print("  ❌  Not enough questions to measure diversity")
        return False

    sim = pairwise_similarity(texts)
    print(f"  Pairwise cosine similarity across {len(texts)} questions:")
    print(f"    avg = {sim['avg']}  (target: < 0.5)")
    print(f"    min = {sim['min']}")
    print(f"    max = {sim['max']}  (target: < 0.8)")

    avg_ok = sim["avg"] < 0.5
    max_ok = sim["max"] < 0.8
    print_result("Average similarity < 0.5", avg_ok, str(sim["avg"]))
    print_result("Max similarity < 0.8",     max_ok, str(sim["max"]))

    return avg_ok and max_ok

# ── Test 5: Open-ended Quality ────────────────────────────────────────────────

def test_open_quality():
    print_section(f"OPEN-ENDED QUALITY  (n={OPEN_COUNT})")
    r = requests.post(f"{BASE_URL}/generate-open-batch", json={
        "subject":      SUBJECT,
        "college":      COLLEGE,
        "count":        OPEN_COUNT,
        "exam_type":    "midsem",
        "with_answers": True,
        "k": 5,
    }, timeout=120)

    if r.status_code != 200:
        print(f"  ❌  Request failed: {r.status_code} {r.text}")
        return False

    questions = r.json().get("questions", [])
    generated = len(questions)
    print_result("All requested generated",
                 generated == OPEN_COUNT,
                 f"{generated}/{OPEN_COUNT}")

    has_question    = sum(1 for q in questions if len(q.get("question","")) > 20)
    has_answer      = sum(1 for q in questions if len(q.get("model_answer","")) > 50)
    not_mcq         = sum(1 for q in questions if "A)" not in q.get("question","")
                          and "option" not in q.get("question","").lower())

    print_result("Non-empty questions",     has_question == generated, f"{has_question}/{generated}")
    print_result("Substantive answers",     has_answer   == generated, f"{has_answer}/{generated}")
    print_result("Not MCQ format",          not_mcq      == generated, f"{not_mcq}/{generated}")

    print("\n  --- Questions for manual review ---")
    for i, q in enumerate(questions, 1):
        print(f"\n  Q{i} ({q.get('marks')} marks): {q['question'][:120]}...")
        print(f"  Answer preview: {q.get('model_answer','')[:100]}...")

    return has_question == generated and has_answer == generated

# ── Test 6: Open-ended Diversity ──────────────────────────────────────────────

def test_open_diversity():
    print_section(f"OPEN-ENDED DIVERSITY  (n={OPEN_COUNT})")
    r = requests.post(f"{BASE_URL}/generate-open-batch", json={
        "subject":      SUBJECT,
        "college":      COLLEGE,
        "count":        OPEN_COUNT,
        "exam_type":    "midsem",
        "with_answers": False,
        "k": 5,
    }, timeout=120)

    if r.status_code != 200:
        print(f"  ❌  Request failed")
        return False

    questions = r.json().get("questions", [])
    texts = [q["question"] for q in questions]

    if len(texts) < 2:
        print("  ❌  Not enough questions to measure diversity")
        return False

    sim = pairwise_similarity(texts)
    print(f"  Pairwise cosine similarity across {len(texts)} questions:")
    print(f"    avg = {sim['avg']}  (target: < 0.5)")
    print(f"    min = {sim['min']}")
    print(f"    max = {sim['max']}  (target: < 0.8)")

    avg_ok = sim["avg"] < 0.5
    max_ok = sim["max"] < 0.8
    print_result("Average similarity < 0.5", avg_ok, str(sim["avg"]))
    print_result("Max similarity < 0.8",     max_ok, str(sim["max"]))

    return avg_ok and max_ok

# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n🔬 Skolar AI — Pipeline Evaluation")
    print(f"   College : {COLLEGE}")
    print(f"   Subject : {SUBJECT}")
    print(f"   API     : {BASE_URL}")

    results = {}
    results["health"]        = test_health()
    if not results["health"]:
        print("\n❌ Server not reachable. Start with: uvicorn main:app --reload --port 8000")
        exit(1)

    results["stats"]         = test_stats()
    results["mcq_accuracy"]  = test_mcq_accuracy()
    results["mcq_diversity"] = test_mcq_diversity()
    results["open_quality"]  = test_open_quality()
    results["open_diversity"]= test_open_diversity()

    print_section("FINAL RESULTS")
    all_passed = True
    for name, passed in results.items():
        print_result(name.replace("_", " ").title(), passed)
        if not passed:
            all_passed = False

    print(f"\n  {'All tests passed!' if all_passed else '⚠️ Some tests failed — see details above'}")
    print()