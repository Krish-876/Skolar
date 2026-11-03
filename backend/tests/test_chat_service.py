import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.services.chat_service import _parse_response_to_chat_response, _sanitize_output, _strip_internal_identifiers


def test_strip_internal_identifiers_removes_ids_and_timestamps_but_keeps_falsy_values():
    payload = {
        "user_id": "abc-123",
        "career_path_id": "path-9",
        "created_at": "2025-01-01T00:00:00Z",
        "empty_list": [],
        "zero": 0,
        "flag": False,
        "nested": {
            "topic_id": "topic-2",
            "updated_at": "2025-02-01T00:00:00Z",
            "keep": "value",
        },
    }

    result = _strip_internal_identifiers(payload)

    assert result == {
        "empty_list": [],
        "zero": 0,
        "flag": False,
        "nested": {"keep": "value"},
    }


def test_sanitize_output_blocks_raw_snapshot_json_and_context_tags():
    leaked = '<student_context>{"academic_year": 2025, "branch": "CS"}</student_context>'
    assert _sanitize_output(leaked) == "I'm here to help with your academic prep and career goals. What would you like to work on?"

    prose_leak = "Here is the student snapshot: academic_year=2025 and branch=CS"
    assert _sanitize_output(prose_leak) == "I'm here to help with your academic prep and career goals. What would you like to work on?"


def test_parse_response_blocks_structured_snapshot_payloads():
    raw = '{"type":"chat","message":"Here is the student data: {\\"academic_year\\": 2025, \\"standing_flags\\": [\\"on_track\\"]}","data": null}'

    parsed = _parse_response_to_chat_response(raw)

    assert parsed.type == "chat"
    assert parsed.message == "I'm here to help with your academic prep and career goals. What would you like to work on?"
    assert parsed.data is None
