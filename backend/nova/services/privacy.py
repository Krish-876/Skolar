"""Policy enforcement for data sent outside the trusted application boundary."""

from __future__ import annotations

import re
from typing import Any


class PrivacyPolicyError(ValueError):
    """Raised when a payload cannot be safely inspected."""


_DIRECT_IDENTIFIER_FIELDS = frozenset(
    {
        "email",
        "email_address",
        "phone",
        "phone_number",
        "full_name",
        "roll_number",
        "roll_no",
        "student_roll_number",
        "user_id",
    }
)
_EMAIL_PATTERN = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
_PHONE_PATTERN = re.compile(r"(?<!\d)\+?\d[\d\s().-]{7,}\d(?!\d)")
_ROLL_PATTERN = re.compile(
    r"\b(?:roll(?:\s*number|\s*no\.?)?|registration(?:\s*number|\s*no\.?)?)"
    r"\s*(?::|#|-|is|=)?\s*[A-Z0-9][A-Z0-9/-]{2,}\b",
    re.IGNORECASE,
)


def _sanitize_text(value: str) -> str:
    value = _EMAIL_PATTERN.sub("[REDACTED_EMAIL]", value)
    value = _PHONE_PATTERN.sub("[REDACTED_PHONE]", value)
    return _ROLL_PATTERN.sub("[REDACTED_ROLL_NUMBER]", value)


def sanitize_for_external(payload: Any) -> Any:
    """Return a safe copy while preserving permitted academic attributes.

    Structured direct-identifier fields are redacted by field name. Free text
    is additionally checked for common email, phone, and roll-number forms.
    Unsupported objects fail closed instead of being stringified and sent.
    """
    if payload is None or isinstance(payload, (bool, int, float)):
        return payload
    if isinstance(payload, str):
        return _sanitize_text(payload)
    if isinstance(payload, list):
        return [sanitize_for_external(item) for item in payload]
    if isinstance(payload, tuple):
        return [sanitize_for_external(item) for item in payload]
    if isinstance(payload, dict):
        sanitized: dict[str, Any] = {}
        for key, value in payload.items():
            if not isinstance(key, str):
                raise PrivacyPolicyError("Payload contains a non-string field name.")
            if key.casefold() in _DIRECT_IDENTIFIER_FIELDS:
                sanitized[key] = "[REDACTED]"
            else:
                sanitized[key] = sanitize_for_external(value)
        return sanitized
    raise PrivacyPolicyError("Payload contains an unsupported value type.")
