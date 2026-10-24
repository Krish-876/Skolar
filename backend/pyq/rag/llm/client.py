import os
import threading
import time
from collections import deque

from groq import Groq
from nova.services.privacy import sanitize_for_external

GROQ_MODEL = "openai/gpt-oss-120b"

_groq_client = None

def get_groq_client():
    global _groq_client
    if _groq_client is None:
        _groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    return _groq_client


# ── Token-budget rate limiting ────────────────────────────────────────────────
# Groq's free tier caps TOKENS per minute, not requests per minute (8000 TPM
# as of writing). At ~800-1200 prompt tokens per generation call, that's a
# real ceiling of roughly 9 calls/minute -- far below what a few concurrent
# ThreadPoolExecutor workers can fire. Every Groq call in this codebase must
# go through create_chat_completion() below so that ceiling is actually
# enforced, instead of relying on the SDK's post-hoc 429 retries (which
# themselves consume budget and just delay the inevitable).

DEFAULT_GROQ_TPM_LIMIT = 8000


def _tpm_limit_from_env() -> int:
    raw = os.getenv("GROQ_TPM_LIMIT")
    return int(raw) if raw else DEFAULT_GROQ_TPM_LIMIT


class TokenBudgetLimiter:
    """Thread-safe rolling-60s token-budget limiter.

    acquire(estimated_tokens) blocks until issuing a call of that estimated
    cost would not push the rolling window over `limit`, then reserves that
    many tokens against the window and returns a reservation id.
    reconcile(reservation_id, actual_tokens) replaces the estimate with the
    real cost reported by the API response, so later callers see an accurate
    total rather than one order-of-magnitude off in whichever direction the
    estimate erred.

    `clock`/`sleep` are injectable so tests can drive this with a fake clock
    instead of actually sleeping.
    """

    def __init__(
        self,
        limit: int | None = None,
        window_seconds: float = 60.0,
        clock=time.monotonic,
        sleep=time.sleep,
    ):
        self.limit = limit if limit is not None else _tpm_limit_from_env()
        self.window_seconds = window_seconds
        self._clock = clock
        self._sleep = sleep
        self._lock = threading.Lock()
        self._events: deque[tuple[float, int, int]] = deque()  # (timestamp, tokens, reservation_id)
        self._next_id = 0

    def _prune_locked(self, now: float) -> None:
        while self._events and now - self._events[0][0] >= self.window_seconds:
            self._events.popleft()

    def _used_locked(self) -> int:
        return sum(tokens for _, tokens, _ in self._events)

    def acquire(self, estimated_tokens: int) -> int:
        while True:
            with self._lock:
                now = self._clock()
                self._prune_locked(now)
                used = self._used_locked()
                # Reserve immediately if it fits, or if the window is empty --
                # the latter lets a single oversized call through rather than
                # blocking forever on a request the budget could never satisfy.
                if not self._events or used + estimated_tokens <= self.limit:
                    reservation_id = self._next_id
                    self._next_id += 1
                    self._events.append((now, estimated_tokens, reservation_id))
                    return reservation_id
                wait_for = self.window_seconds - (now - self._events[0][0])
            self._sleep(max(wait_for, 0.01))

    def reconcile(self, reservation_id: int, actual_tokens: int) -> None:
        with self._lock:
            for i, (ts, _tokens, rid) in enumerate(self._events):
                if rid == reservation_id:
                    self._events[i] = (ts, actual_tokens, rid)
                    return
            # Reservation already aged out of the window -- nothing to fix up.


_limiter_lock = threading.Lock()
_token_limiter: TokenBudgetLimiter | None = None


def get_token_limiter() -> TokenBudgetLimiter:
    global _token_limiter
    if _token_limiter is None:
        with _limiter_lock:
            if _token_limiter is None:
                _token_limiter = TokenBudgetLimiter()
    return _token_limiter


def estimate_prompt_tokens(messages: list[dict]) -> int:
    """~4 chars/token is the standard rough heuristic for English text --
    good enough to reserve budget ahead of the real usage figure."""
    chars = sum(len(m.get("content", "")) for m in messages)
    return max(1, chars // 4)


# Groq's TPM ceiling counts prompt + completion tokens combined, but none of
# this codebase's callers pass max_completion_tokens, so the completion side
# is open-ended. estimate_call_tokens() below must budget for it -- reserving
# on the prompt alone means acquire() lets a call through, the call then
# spends an extra several-hundred completion tokens Groq bills against the
# account's real TPM counter, and reconcile() only learns the true cost once
# the response is already back. With concurrent ThreadPoolExecutor workers
# (services/generate.py), several calls can be in flight at once each holding
# one of these too-small reservations, so the local window under-counts by
# their combined completion cost and a burst can blow through Groq's actual
# limit and 429 even though the local bookkeeping still looked fine.
# generate_model_answer's own prompt caps the longest case at "under 250
# words" of markdown -- ~450 tokens is a safe ceiling for that plus overhead.
DEFAULT_COMPLETION_TOKENS_ESTIMATE = 450


def _completion_tokens_estimate_from_env() -> int:
    raw = os.getenv("GROQ_COMPLETION_TOKENS_ESTIMATE")
    return int(raw) if raw else DEFAULT_COMPLETION_TOKENS_ESTIMATE


def estimate_call_tokens(messages: list[dict], max_completion_tokens: int | None = None) -> int:
    """Upper-bound estimate of a call's total token cost (prompt + completion)
    to reserve against the shared TPM budget. Uses the caller's explicit
    max_completion_tokens/max_tokens cap when given, else a conservative
    fixed estimate -- see DEFAULT_COMPLETION_TOKENS_ESTIMATE."""
    completion_budget = (
        max_completion_tokens if max_completion_tokens is not None
        else _completion_tokens_estimate_from_env()
    )
    return estimate_prompt_tokens(messages) + completion_budget


def create_chat_completion(*, messages: list[dict], **kwargs):
    """Rate-limited wrapper around client.chat.completions.create. Every Groq
    call in this codebase should go through this rather than the raw client,
    so the shared token budget is actually enforced across all callers/threads."""
    client = get_groq_client()
    limiter = get_token_limiter()
    safe_messages = sanitize_for_external(messages)

    max_completion_tokens = kwargs.get("max_completion_tokens", kwargs.get("max_tokens"))
    estimated = estimate_call_tokens(safe_messages, max_completion_tokens)
    reservation_id = limiter.acquire(estimated)

    response = client.chat.completions.create(messages=safe_messages, **kwargs)

    usage = getattr(response, "usage", None)
    actual = usage.total_tokens if usage is not None else estimated
    limiter.reconcile(reservation_id, actual)

    return response
