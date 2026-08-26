"""
Measures the real token size of a student's FactsSnapshot JSON dump.

Spec ref: nova-provider-hierarchy-v3.md, "Open items" #1 - this gates
whether Cerebras' 8K context cap is usable at all, how close the reasoning
layer's 8K TPM cap is to binding, and how much the caching split in §1/§4
actually saves. Run this against a real user before tuning any of that.

Usage:
    python -m nova.scripts.measure_facts_tokens <user_id>

Uses tiktoken if installed (accurate); falls back to chat_service's own
chars/4 estimator otherwise (same estimator the resilience wrapper uses
for its TPM gate checks, so the fallback number is at least consistent
with what production actually gates on).
"""
import json
import sys

from nova.services.chat_service import _estimate_tokens as _char_estimate
from nova.services.clients import get_clients
from nova.services.facts_service import get_facts_snapshot

try:
    import tiktoken

    _ENC = tiktoken.get_encoding("cl100k_base")

    def _accurate_tokens(text: str) -> int:
        return len(_ENC.encode(text))

    _HAVE_TIKTOKEN = True
except ImportError:
    _HAVE_TIKTOKEN = False


def _tokens_for(text: str) -> int:
    if _HAVE_TIKTOKEN:
        return _accurate_tokens(text)
    return _char_estimate([{"content": text}])


def main():
    if len(sys.argv) != 2:
        print("Usage: python -m nova.scripts.measure_facts_tokens <user_id>")
        sys.exit(1)
    user_id = sys.argv[1]

    if not _HAVE_TIKTOKEN:
        print("(tiktoken not installed - falling back to chars/4 estimate, "
              "the same one chat_service.py's TPM gate uses. "
              "`pip install tiktoken` for an accurate count.)\n")

    supabase, _groq, _groq_backup = get_clients()
    snapshot = get_facts_snapshot(supabase, user_id)
    dump = snapshot.model_dump()

    full_json = json.dumps(dump, default=str)
    total_tokens = _tokens_for(full_json)

    print(f"user_id: {user_id}")
    print(f"row_count: {snapshot.row_count()}")
    print(f"full snapshot JSON: {len(full_json)} chars, ~{total_tokens} tokens\n")

    print("Per-field breakdown (sorted, largest first):")
    field_tokens = []
    for field, value in dump.items():
        field_json = json.dumps(value, default=str)
        field_tokens.append((field, _tokens_for(field_json), len(field_json)))
    field_tokens.sort(key=lambda x: -x[1])
    for field, tok, chars in field_tokens:
        pct = (tok / total_tokens * 100) if total_tokens else 0
        print(f"  {field:<24} ~{tok:>6} tok  ({chars:>7} chars, {pct:5.1f}%)")

    print("\nGate checks against the limits in the spec:")
    print(f"  Cerebras shadow-eval cap (8,192 tok):        "
          f"{'OK' if total_tokens <= 8192 else 'OVER by ' + str(total_tokens - 8192)}")
    print(f"  ask_nova / reasoning_layer TPM cap (8,000 tok, snapshot only): "
          f"{'OK' if total_tokens <= 8000 else 'OVER by ' + str(total_tokens - 8000)}")
    print("  (note: ask_nova's real per-call total also includes "
          "NOVA_SYSTEM_PROMPT + conversation history + the question itself, "
          "not just the snapshot measured here - add those before trusting "
          "the ask_nova line above as a full-call guarantee.)")


if __name__ == "__main__":
    main()