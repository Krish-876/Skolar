"""Request rate limiting for the API security pipeline."""

from __future__ import annotations

import math
import threading
import time
from collections import deque
from dataclasses import dataclass
from typing import Callable, Deque, Dict, Tuple


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    retry_after: int | None = None


class SlidingWindowRateLimiter:
    """Thread-safe, single-process sliding-window request limiter."""

    def __init__(
        self,
        limits: Dict[str, Tuple[int, float]],
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limits = self._validate_limits(limits)
        self._clock = clock
        self._events: Dict[Tuple[str, str], Deque[float]] = {}
        self._lock = threading.Lock()

    @staticmethod
    def _validate_limits(
        limits: Dict[str, Tuple[int, float]],
    ) -> Dict[str, Tuple[int, float]]:
        validated: Dict[str, Tuple[int, float]] = {}
        for category, (maximum, window_seconds) in limits.items():
            if maximum <= 0 or window_seconds <= 0:
                raise ValueError("Rate-limit maximum and window must be positive.")
            validated[category] = (maximum, float(window_seconds))
        return validated

    def check(self, key: str, category: str) -> RateLimitDecision:
        """Reserve one request slot and return the enforcement decision."""
        if category not in self._limits:
            raise KeyError(f"Unknown rate-limit category: {category}")

        maximum, window_seconds = self._limits[category]
        now = self._clock()
        event_key = (category, key)

        with self._lock:
            self._prune_expired(now)
            events = self._events.setdefault(event_key, deque())

            if len(events) >= maximum:
                retry_after = max(1, math.ceil(events[0] + window_seconds - now))
                return RateLimitDecision(False, retry_after)

            events.append(now)
            return RateLimitDecision(True)

    def _prune_expired(self, now: float) -> None:
        """Remove expired reservations, including keys inactive since their last request."""
        for event_key, events in list(self._events.items()):
            category, _ = event_key
            cutoff = now - self._limits[category][1]
            while events and events[0] <= cutoff:
                events.popleft()
            if not events:
                del self._events[event_key]

    def clear(self) -> None:
        """Clear reservations; intended for test isolation and local reset."""
        with self._lock:
            self._events.clear()
