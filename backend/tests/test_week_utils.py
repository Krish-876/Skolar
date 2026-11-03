"""
Unit tests for nova.services.week_utils.week_start_for.

Validates the Python implementation is bit-for-bit compatible with the Dart
weekStartFor in lib/core/utils/week_utils.dart:

    DateTime weekStartFor(DateTime localDate, int startDay) {
      final d = DateTime(localDate.year, localDate.month, localDate.day);
      final dayOfWeek = d.weekday;        // 1=Mon ... 7=Sun
      final offset = (dayOfWeek - startDay) % 7;
      return DateTime(d.year, d.month, d.day - offset);
    }

Coverage:
- Every weekday (Mon-Sun) with Sunday-start (startDay=7)
- Every weekday (Mon-Sun) with Monday-start (startDay=1)
- Identity: when localDate itself IS the start day, offset == 0
- Boundary: start of week lands on a month boundary (e.g. Oct 5 -> Sep 28)
- Leap year: Feb 29 present and correct
- All start_day values 1..7 spot-checked against a fixed reference date
- Invalid start_day raises ValueError
"""

import sys
from datetime import date
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.services.week_utils import week_start_for  # noqa: E402


# ---------------------------------------------------------------------------
# Reference: Monday 2026-10-05, the week that contains our test dates
# Sun 2026-10-04, Mon 2026-10-05, ..., Sat 2026-10-10
# ---------------------------------------------------------------------------

class TestSundayStart:
    """start_day=7 (Sunday) -- the nova_config default."""

    # Each (input_date, expected_week_start) pair.
    # The containing Sunday-start week is Sun 2026-10-04 ... Sat 2026-10-10.
    @pytest.mark.parametrize(
        "input_iso, expected_iso",
        [
            ("2026-10-04", "2026-10-04"),   # Sun -- identity
            ("2026-10-05", "2026-10-04"),   # Mon
            ("2026-10-06", "2026-10-04"),   # Tue
            ("2026-10-07", "2026-10-04"),   # Wed
            ("2026-10-08", "2026-10-04"),   # Thu
            ("2026-10-09", "2026-10-04"),   # Fri
            ("2026-10-10", "2026-10-04"),   # Sat
        ],
    )
    def test_every_weekday(self, input_iso: str, expected_iso: str) -> None:
        result = week_start_for(date.fromisoformat(input_iso), 7)
        assert result.isoformat() == expected_iso


class TestMondayStart:
    """start_day=1 (Monday)."""

    # Mon 2026-10-05 ... Sun 2026-10-11
    @pytest.mark.parametrize(
        "input_iso, expected_iso",
        [
            ("2026-10-05", "2026-10-05"),   # Mon -- identity
            ("2026-10-06", "2026-10-05"),   # Tue
            ("2026-10-07", "2026-10-05"),   # Wed
            ("2026-10-08", "2026-10-05"),   # Thu
            ("2026-10-09", "2026-10-05"),   # Fri
            ("2026-10-10", "2026-10-05"),   # Sat
            ("2026-10-11", "2026-10-05"),   # Sun
        ],
    )
    def test_every_weekday(self, input_iso: str, expected_iso: str) -> None:
        result = week_start_for(date.fromisoformat(input_iso), 1)
        assert result.isoformat() == expected_iso


class TestOtherStartDays:
    """Spot-check Wednesday (3), Thursday (4), Friday (5), Saturday (6) starts."""

    @pytest.mark.parametrize(
        "start_day, input_iso, expected_iso",
        [
            (2, "2026-10-06", "2026-10-06"),   # Tue: identity
            (2, "2026-10-07", "2026-10-06"),   # Wed -> previous Tue
            (3, "2026-10-05", "2026-09-30"),   # Mon -> prev Wed (Sep 30)
            (3, "2026-10-07", "2026-10-07"),   # Wed: identity
            (4, "2026-10-08", "2026-10-08"),   # Thu: identity
            (4, "2026-10-09", "2026-10-08"),   # Fri -> Thu
            (5, "2026-10-09", "2026-10-09"),   # Fri: identity
            (5, "2026-10-10", "2026-10-09"),   # Sat -> Fri
            (6, "2026-10-10", "2026-10-10"),   # Sat: identity
            (6, "2026-10-11", "2026-10-10"),   # Sun -> Sat
        ],
    )
    def test_spot_check(self, start_day: int, input_iso: str, expected_iso: str) -> None:
        result = week_start_for(date.fromisoformat(input_iso), start_day)
        assert result.isoformat() == expected_iso


class TestBoundaryAndEdgeCases:
    def test_month_boundary_sunday_start(self) -> None:
        """Oct 2 2026 (Fri, isoweekday=5) with Sunday-start.
        offset = (5 - 7) % 7 = 5  =>  Oct 2 - 5 = Sep 27 (Sun)."""
        result = week_start_for(date(2026, 10, 2), 7)
        assert result == date(2026, 9, 27)

    def test_year_boundary_sunday_start(self) -> None:
        """Jan 1 2026 (Thu) with Sunday-start -> Dec 28 2025 (Sun)."""
        result = week_start_for(date(2026, 1, 1), 7)
        assert result == date(2025, 12, 28)

    def test_year_boundary_monday_start(self) -> None:
        """Jan 1 2026 (Thu) with Monday-start -> Dec 29 2025 (Mon)."""
        result = week_start_for(date(2026, 1, 1), 1)
        assert result == date(2025, 12, 29)

    def test_leap_year_feb29(self) -> None:
        """Feb 29 2028 (Tue) with Sunday-start -> Feb 27 2028 (Sun)."""
        result = week_start_for(date(2028, 2, 29), 7)
        assert result == date(2028, 2, 27)

    def test_leap_year_feb29_monday_start(self) -> None:
        """Feb 29 2028 (Tue) with Monday-start -> Feb 28 2028 (Mon)."""
        result = week_start_for(date(2028, 2, 29), 1)
        assert result == date(2028, 2, 28)


class TestDartCompatibility:
    """Mirror Dart``s own doc example verbatim.

    weekStartFor(DateTime(2026, 10, 5), 7) -> DateTime(2026, 10, 4)
    (Sunday), which is the start of the week containing Mon Oct 5, 2026.
    """

    def test_dart_doc_example(self) -> None:
        result = week_start_for(date(2026, 10, 5), 7)
        assert result == date(2026, 10, 4)

    def test_start_day_is_the_week_start(self) -> None:
        """When the input IS the start day, the offset must be 0."""
        # Sun Oct 4 with Sunday-start
        result = week_start_for(date(2026, 10, 4), 7)
        assert result == date(2026, 10, 4)

    def test_offset_formula_spot_check(self) -> None:
        """Verify offset = (dayOfWeek - startDay) % 7 for all 7 weekdays
        across both Sunday-start and Monday-start to make certain the modular
        arithmetic never wraps negative."""
        week_sun = date(2026, 10, 4)   # the Sunday
        for day_offset in range(7):
            d = date(2026, 10, 4 + day_offset)
            result_sun = week_start_for(d, 7)
            assert result_sun == week_sun, f"Sunday-start failed for {d}: got {result_sun}"

        week_mon = date(2026, 10, 5)   # the Monday
        for day_offset in range(7):
            d = date(2026, 10, 5 + day_offset)
            result_mon = week_start_for(d, 1)
            assert result_mon == week_mon, f"Monday-start failed for {d}: got {result_mon}"


class TestInvalidInput:
    @pytest.mark.parametrize("bad", [0, 8, -1, 100])
    def test_invalid_start_day_raises(self, bad: int) -> None:
        with pytest.raises(ValueError, match="start_day must be"):
            week_start_for(date(2026, 10, 5), bad)
