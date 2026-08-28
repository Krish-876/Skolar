"""
Unit tests for llm/client.py's TokenBudgetLimiter -- the shared token-budget
rate limiter every Groq call routes through (see create_chat_completion).

Groq's free tier caps TOKENS per minute (8000 TPM), not requests, so this
limiter tracks tokens consumed in a rolling 60s window rather than a request
count. All blocking tests use an injected fake clock/sleep -- no real
sleeping -- per the task's requirement.
"""

import sys
import threading
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.llm.client import (  # noqa: E402
    DEFAULT_COMPLETION_TOKENS_ESTIMATE,
    TokenBudgetLimiter,
    estimate_call_tokens,
    estimate_prompt_tokens,
)


class FakeClock:
    def __init__(self, start: float = 0.0):
        self.now = start

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


def _fake_sleep_and_clock():
    clock = FakeClock()
    calls: list[float] = []

    def fake_sleep(seconds: float) -> None:
        calls.append(seconds)
        clock.advance(seconds)

    return clock, fake_sleep, calls


# ── Blocking / rollover ────────────────────────────────────────────────────────

def test_acquire_does_not_block_when_under_budget():
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    limiter.acquire(300)
    limiter.acquire(300)

    assert calls == []


def test_acquire_blocks_when_window_budget_exhausted():
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    limiter.acquire(900)          # fits, no block
    assert calls == []

    limiter.acquire(200)          # 900 + 200 > 1000 -- must block
    assert calls != []


def test_acquire_releases_budget_after_window_rolls_over():
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    limiter.acquire(900)
    limiter.acquire(200)          # blocks until the first reservation ages out

    # The blocking sleep should have advanced the clock by (about) the full
    # window, since the only in-flight reservation was made at t=0.
    assert clock.now >= 60.0
    assert sum(calls) >= 60.0

    # Budget is now free again -- a further call that fits must not block.
    calls_before = len(calls)
    limiter.acquire(500)
    assert len(calls) == calls_before


def test_acquire_lets_a_single_oversized_call_through_on_empty_window():
    # A request larger than the whole budget must not hang forever when
    # nothing else is in flight.
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    limiter.acquire(5000)

    assert calls == []


# ── reconcile ──────────────────────────────────────────────────────────────────

def test_reconcile_replaces_estimate_with_actual_usage():
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    reservation_id = limiter.acquire(900)   # overestimated
    limiter.reconcile(reservation_id, 200)  # actual usage was much lower

    # Budget should reflect the corrected (lower) usage -- a call that would
    # have exceeded the original 900+X estimate now fits without blocking.
    limiter.acquire(500)
    assert calls == []


def test_reconcile_on_aged_out_reservation_is_a_noop():
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    reservation_id = limiter.acquire(100)
    clock.advance(61)
    limiter.acquire(50)  # prunes the aged-out reservation as a side effect

    limiter.reconcile(reservation_id, 999)  # must not raise


# ── thread-safety ────────────────────────────────────────────────────────────

def test_acquire_is_thread_safe_no_lost_or_duplicate_reservations():
    # Generous limit + real clock/sleep so nothing actually blocks -- this
    # tests the lock's correctness under concurrency, not blocking behaviour.
    limiter = TokenBudgetLimiter(limit=10_000_000, window_seconds=60.0)

    results: list[int] = []
    results_lock = threading.Lock()

    def worker():
        reservation_id = limiter.acquire(10)
        with results_lock:
            results.append(reservation_id)

    threads = [threading.Thread(target=worker) for _ in range(50)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert len(results) == 50
    assert len(set(results)) == 50


# ── estimate_prompt_tokens ────────────────────────────────────────────────────

def test_estimate_prompt_tokens_scales_with_content_length():
    short = estimate_prompt_tokens([{"role": "user", "content": "hi"}])
    long = estimate_prompt_tokens([{"role": "user", "content": "x" * 4000}])

    assert short >= 1
    assert long > short


def test_estimate_prompt_tokens_sums_across_messages():
    single = estimate_prompt_tokens([{"role": "user", "content": "x" * 400}])
    two = estimate_prompt_tokens([
        {"role": "system", "content": "x" * 400},
        {"role": "user", "content": "x" * 400},
    ])
    assert two == 2 * single


# ── estimate_call_tokens ─────────────────────────────────────────────────────
# The gap: estimate_prompt_tokens alone only budgets the prompt side of a
# call, but Groq's TPM ceiling counts prompt + completion tokens together and
# no caller here bounds completion length. A reservation based on the prompt
# alone understates the real cost of every call by however many tokens the
# completion consumes, which reconcile() only corrects *after* the response
# (and Groq's real usage) has already happened -- letting concurrent workers
# burst past the account's actual limit even while the local window still
# looks fine. estimate_call_tokens() must add a completion budget.

def test_estimate_call_tokens_adds_default_completion_budget_when_uncapped():
    messages = [{"role": "user", "content": "x" * 400}]
    prompt_only = estimate_prompt_tokens(messages)

    total = estimate_call_tokens(messages)

    assert total == prompt_only + DEFAULT_COMPLETION_TOKENS_ESTIMATE


def test_estimate_call_tokens_uses_explicit_max_completion_tokens_when_given():
    messages = [{"role": "user", "content": "x" * 400}]
    prompt_only = estimate_prompt_tokens(messages)

    total = estimate_call_tokens(messages, max_completion_tokens=50)

    assert total == prompt_only + 50


def test_acquire_reserves_more_than_prompt_alone_would_understate():
    # Reproduces the gap directly: two back-to-back calls whose *prompt*
    # tokens fit comfortably under the limit, but whose real (prompt +
    # completion) cost does not, must still be throttled by acquire().
    clock, fake_sleep, calls = _fake_sleep_and_clock()
    limiter = TokenBudgetLimiter(limit=1000, window_seconds=60.0, clock=clock, sleep=fake_sleep)

    messages = [{"role": "user", "content": "x" * 400}]  # ~100 prompt tokens
    assert estimate_prompt_tokens(messages) < 200

    limiter.acquire(estimate_call_tokens(messages, max_completion_tokens=700))
    assert calls == []

    limiter.acquire(estimate_call_tokens(messages, max_completion_tokens=700))
    assert calls != []  # a prompt-only estimate would never have blocked here
