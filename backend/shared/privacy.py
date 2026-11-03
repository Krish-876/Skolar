"""Privacy policy for payloads sent outside the trusted application boundary."""

from __future__ import annotations

import re
from typing import Any


class PrivacyPolicyError(ValueError):
    """Raised when a payload cannot be safely inspected."""


_DIRECT_IDENTIFIER_FIELDS = frozenset({
    "email", "email_address", "phone", "phone_number", "full_name",
    "roll_number", "roll_no", "student_roll_number", "user_id",
})
_EMAIL_PATTERN = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
_PHONE_PATTERN = re.compile(
    r"(?<!\d)(?:\+\d{1,3}[\s().-]*)?(?:\d[\s().-]*){10,}(?!\d)"
)
_ROLL_PATTERN = re.compile(
    r"\b(?:roll(?:\s*number|\s*no\.?)?|registration(?:\s*number|\s*no\.?)?)"
    r"\s*(?::|#|-|is|=)?\s*[A-Z0-9][A-Z0-9/-]{2,}\b", re.IGNORECASE,
)


def _sanitize_text(value: str) -> str:
    value = _EMAIL_PATTERN.sub("[REDACTED_EMAIL]", value)
    value = _PHONE_PATTERN.sub("[REDACTED_PHONE]", value)
    return _ROLL_PATTERN.sub("[REDACTED_ROLL_NUMBER]", value)


def sanitize_for_external(payload: Any) -> Any:
    if payload is None or isinstance(payload, (bool, int, float)):
        return payload
    if isinstance(payload, str):
        return _sanitize_text(payload)
    if isinstance(payload, (list, tuple)):
        return [sanitize_for_external(item) for item in payload]
    if isinstance(payload, dict):
        sanitized: dict[str, Any] = {}
        for key, value in payload.items():
            if not isinstance(key, str):
                raise PrivacyPolicyError("Payload contains a non-string field name.")
            sanitized[key] = (
                "[REDACTED]" if key.casefold() in _DIRECT_IDENTIFIER_FIELDS
                else sanitize_for_external(value)
            )
        return sanitized
    raise PrivacyPolicyError("Payload contains an unsupported value type.")
