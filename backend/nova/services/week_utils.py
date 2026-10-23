"""
Week-boundary helper -- Python port of ``lib/core/utils/week_utils.dart``.

``week_start_for(local_date, start_day)`` returns the most-recent calendar
date whose day-of-week equals ``start_day``, using **Dart's** ``DateTime.weekday``
convention (1 = Monday ... 7 = Sunday), so the result always agrees with the
Dart dashboard calculation.

The global ``nova_config`` row ``week_start_day`` stores ``7`` (Sunday) as
the default.  Pass whatever value is in that row directly as ``start_day``.

This module has no external dependencies and no side effects -- all functions
are pure and do not read ``date.today()`` internally.
"""

from datetime import date, timedelta


def week_start_for(local_date: date, start_day: int) -> date:
    """Return the start of the calendar week containing *local_date*.

    Parameters
    ----------
    local_date:
        The device-local date (caller must supply; server ``date.today()``
        must not be used here -- device and server may disagree by a day).
    start_day:
        First day of the week using Dart's ``DateTime.weekday`` convention:
        ``1`` = Monday, ``2`` = Tuesday, ..., ``7`` = Sunday.

    Returns
    -------
    date
        The date of the most-recent occurrence of *start_day* that is
        ``<= local_date``.  If *local_date* itself falls on *start_day*
        the input date is returned unchanged.

    Raises
    ------
    ValueError
        If *start_day* is outside the range ``1..7``.

    Examples
    --------
    >>> from datetime import date
    >>> week_start_for(date(2026, 10, 5), 7)   # Mon Oct 5, Sunday-start
    datetime.date(2026, 10, 4)
    >>> week_start_for(date(2026, 10, 4), 7)   # Sun Oct 4, Sunday-start
    datetime.date(2026, 10, 4)
    >>> week_start_for(date(2026, 10, 5), 1)   # Mon Oct 5, Monday-start
    datetime.date(2026, 10, 5)

    Dart reference (``lib/core/utils/week_utils.dart``)::

        final dayOfWeek = d.weekday;      // 1=Mon ... 7=Sun
        final offset = (dayOfWeek - startDay) % 7;
        return DateTime(d.year, d.month, d.day - offset);

    Python's ``date.weekday()`` returns 0=Mon ... 6=Sun, but Dart returns
    1=Mon ... 7=Sun.  We use Python's ``isoweekday()`` (1=Mon ... 7=Sun) which
    matches Dart exactly, so the modulo expression is identical.
    """
    if not (1 <= start_day <= 7):
        raise ValueError(f"start_day must be 1 (Mon) ... 7 (Sun), got {start_day}")

    day_of_week = local_date.isoweekday()  # 1=Mon ... 7=Sun -- matches Dart
    offset = (day_of_week - start_day) % 7
    return local_date - timedelta(days=offset)
