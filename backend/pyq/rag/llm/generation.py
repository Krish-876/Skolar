import json

from .client import GROQ_MODEL, create_chat_completion

# ── Step 5 — Open-ended Question Generation ───────────────────────────────────

def generate_question(subject: str, examples: list[dict]) -> str:
    examples_text = "\n\n".join(
        f"Example {i+1} ({q.get('marks', '?')} marks, {q.get('question_type', 'unknown')}, topic: {q.get('topic', 'unknown')}):\n{q['question_text']}"
        for i, q in enumerate(examples)
    )
    prompt = f"""You are an exam question generator for {subject}.
Below are example questions from previous exams at this college.
These set the difficulty level and style standard.

{examples_text}

Generate ONE new original exam question in the same style and difficulty range.
Return ONLY the question text. No explanation, no preamble, no label."""

    response = create_chat_completion(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    raw = response.choices[0].message.content.strip()
    import re
    raw = re.sub(r'^(Q\.?\s*\d+[\.\)]\s*|\d+[\.\)]\s*)', '', raw, flags=re.IGNORECASE).strip()
    # Some stored question_text values already carry the few-shot header this
    # module prepends for examples ("{marks} marks, {type}, topic: {topic}:\n") --
    # a leftover of the extraction step. When such a row is used as an example,
    # the model echoes that header back verbatim instead of just the question.
    raw = re.sub(
        r'^\d+\s*marks,\s*[^,\n]+,\s*topic:\s*[^\n]*?:\s*\n+', '', raw, flags=re.IGNORECASE
    ).strip()
    return raw

# ── Step 5b — MCQ Generation ──────────────────────────────────────────────────

def generate_mcq(subject: str, examples: list[dict]) -> dict:
    examples_text = "\n\n".join(
        f"Example {i+1} ({q.get('marks', '?')} marks, topic: {q.get('topic', 'unknown')}):\n{q['question_text']}"
        for i, q in enumerate(examples)
    )
    prompt = f"""You are an exam MCQ generator for {subject}.
Below are example questions from previous exams at this college.
Use them to calibrate the difficulty and topic coverage.

{examples_text}

Generate ONE new original MCQ question at a similar difficulty level.

Return ONLY a valid JSON object with exactly these fields — no markdown, no backticks, no extra text:
{{
  "question": "<full question text>",
  "option_a": "<option text>",
  "option_b": "<option text>",
  "option_c": "<option text>",
  "option_d": "<option text>",
  "correct_index": <0, 1, 2, or 3 — 0=A, 1=B, 2=C, 3=D>,
  "marks": <integer, typically 1 or 2>,
  "subject": "{subject}"
}}"""

    response = create_chat_completion(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    raw = response.choices[0].message.content.strip()
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        raw = raw.removeprefix("json")
    parsed = json.loads(raw.strip())
    return {
        "question":      parsed["question"],
        "options":       [parsed["option_a"], parsed["option_b"], parsed["option_c"], parsed["option_d"]],
        "correct_index": int(parsed["correct_index"]),
        "subject":       parsed.get("subject", subject),
        "marks":         int(parsed.get("marks", 1)),
    }

# ── Step 5c — Model Answer Generation ────────────────────────────────────────

def generate_model_answer(question_text: str, subject: str, marks: int) -> str:
    if marks <= 3:
        structure = (
            "Write 2–3 sentences that DIRECTLY answer this specific question. "
            "If it asks to define, state the definition. "
            "If it asks to explain, give the actual explanation. "
            "Bold key technical terms. No headings, no bullet points."
        )
    elif marks <= 6:
        structure = (
            "DIRECTLY answer this specific question. Do NOT give generic background theory.\n\n"
            "If the question asks to compute, calculate, or derive:\n"
            "  - Show the actual step-by-step working using the specific values given\n"
            "  - Use `### Steps` as the heading\n"
            "  - Each step should show the formula applied with real numbers\n"
            "  - End with the final numerical result\n\n"
            "If the question asks to explain or describe:\n"
            "  - One opening sentence directly answering what is asked\n"
            "  - `### Key points` with 3–4 bullets of substance specific to the question\n"
            "  - Each bullet must add real information, not restate the question\n\n"
            "Keep under 150 words."
        )
    else:
        structure = (
            "DIRECTLY answer this specific question with full working. Do NOT give generic theory.\n\n"
            "If the question contains specific data (numbers, tables, probabilities, matrices):\n"
            "  - Use that exact data in your answer\n"
            "  - Show full step-by-step computation under `### Working`\n"
            "  - Use a markdown table if presenting computed results per state/variable\n"
            "  - Conclude with `### Result` stating the final answer clearly\n\n"
            "If the question asks to explain/compare/design:\n"
            "  - `### Approach` — 2-3 sentences directly answering the question\n"
            "  - `### Explanation` — 3-4 bullets with substance specific to this question\n"
            "  - `### Conclusion` — one sentence summary\n\n"
            "Keep under 250 words. Every sentence must be specific to this question."
        )

    prompt = f"""You are a {subject} professor marking an exam. Write a model answer for the question below worth {marks} marks.

CRITICAL RULE: Your answer must be SPECIFIC to the exact question asked. If the question gives specific numbers, states, probabilities, or data — use them in your answer. Never write a generic answer that could apply to any question.

Question:
{question_text}

Instructions:
{structure}

Strict formatting rules:
- Use **bold** only for key technical terms or final answers
- Use `backticks` for formulas, variable names, or computed values inline
- Use ### for section headings only (no ## or #)
- Use - for bullet points
- For results with multiple states/variables, use a markdown table: | Header | Header | with | --- | --- | separator row
- Do NOT write a preamble like "Here is the answer:" or "Model answer:"
- Do NOT repeat the question text
- Return ONLY the answer markdown, nothing else"""

    response = create_chat_completion(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
    )
    return response.choices[0].message.content.strip()
