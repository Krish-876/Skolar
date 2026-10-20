import json
from types import SimpleNamespace

import pytest

from nova.services.chat_service import ask_nova
from nova.services.privacy import PrivacyPolicyError, sanitize_for_external


class FakeGroq:
    def __init__(self):
        self.messages = None
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self.create))

    def create(self, **kwargs):
        self.messages = kwargs["messages"]
        return SimpleNamespace(
            choices=[
                SimpleNamespace(
                    message=SimpleNamespace(
                        content=json.dumps(
                            {
                                "type": "chat",
                                "message": "Safe response",
                                "data": None,
                                "suggestions": [],
                            }
                        )
                    )
                )
            ]
        )


def _message_text(messages):
    return "\n".join(message["content"] for message in messages)


def test_chat_outbound_payload_redacts_structured_and_free_text_pii():
    groq = FakeGroq()
    snapshot = {
        "full_name": "Asha Student",
        "email": "asha.student@example.com",
        "branch": "Computer Science",
        "current_semester": 4,
        "nested": {"phone_number": "+91 98765 43210"},
    }

    ask_nova(
        groq,
        snapshot,
        "Contact me at asha.student@example.com or +91 98765 43210",
        [SimpleNamespace(role="user", content="My roll number is CSE-2024-007")],
    )

    outbound = _message_text(groq.messages)
    assert "Asha Student" not in outbound
    assert "asha.student@example.com" not in outbound
    assert "98765 43210" not in outbound
    assert "CSE-2024-007" not in outbound
    assert "Computer Science" in outbound
    assert "current_semester" in outbound


def test_privacy_shield_preserves_permitted_academic_attributes_and_nested_data():
    payload = {
        "branch": "Mathematics",
        "semester": 3,
        "nested": {"roll_number": "ROLL-22", "topic": "Calculus"},
    }

    safe = sanitize_for_external(payload)

    assert safe["branch"] == "Mathematics"
    assert safe["semester"] == 3
    assert safe["nested"]["roll_number"] == "[REDACTED]"
    assert safe["nested"]["topic"] == "Calculus"


@pytest.mark.parametrize("value", [object(), {"field": object()}])
def test_privacy_shield_fails_closed_for_unsupported_values(value):
    with pytest.raises(PrivacyPolicyError):
        sanitize_for_external(value)


def test_privacy_shield_handles_missing_and_null_values():
    assert sanitize_for_external({"email": None, "phone": None}) == {
        "email": "[REDACTED]",
        "phone": "[REDACTED]",
    }
