import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import nova.__main__ as cli_main  # noqa: E402
from nova.schemas.api import ChatResponse  # noqa: E402
from nova.schemas.chat import ChatTurn  # noqa: E402
from nova.services.chat_service import ParsedChatResponse  # noqa: E402


def test_cli_main_extracts_message_string_into_history(monkeypatch, capsys):
    test_user_id = "test-user-cli"
    monkeypatch.setattr(sys, "argv", ["nova_agent.py", test_user_id])

    fake_supabase = MagicMock()
    fake_groq = MagicMock()
    monkeypatch.setattr(cli_main, "get_clients", lambda: (fake_supabase, fake_groq, None))
    monkeypatch.setattr(cli_main, "get_supabase_credentials", lambda: ("http://fake", "key"))
    monkeypatch.setattr(cli_main, "start_facts_listener_threaded", MagicMock())

    mock_facts_state = MagicMock()
    mock_facts_snapshot = MagicMock()
    mock_facts_snapshot.model_dump.return_value = {"user_id": test_user_id}
    mock_facts_state.get.return_value = (mock_facts_snapshot, {})
    monkeypatch.setattr(cli_main, "FactsState", lambda _sb, _uid: mock_facts_state)

    # Input: one question, then EOFError to break loop
    user_inputs = iter(["Explain quicksort"])

    def mock_input(_prompt=""):
        try:
            return next(user_inputs)
        except StopIteration:
            raise EOFError

    monkeypatch.setattr("builtins.input", mock_input)

    parsed_response = ParsedChatResponse(
        response=ChatResponse(
            type="chat",
            message="Quicksort is a divide-and-conquer sorting algorithm.",
            data=None,
            suggestions=["Give me an example"],
        ),
        raw_proposed_facts=[],
    )

    with patch("nova.__main__.ask_nova", return_value=parsed_response) as mock_ask:
        with patch("nova.__main__.ChatTurn", wraps=ChatTurn) as mock_chat_turn:
            cli_main.main()

    assert mock_ask.called
    captured = capsys.readouterr().out
    # CLI must print the message string, not the ParsedChatResponse object representation
    assert "Quicksort is a divide-and-conquer sorting algorithm." in captured
    assert "ParsedChatResponse" not in captured

    # Verify ChatTurn received str for role="assistant", not ParsedChatResponse
    assistant_calls = [
        call for call in mock_chat_turn.call_args_list if call.kwargs.get("role") == "assistant"
    ]
    assert len(assistant_calls) == 1
    assert assistant_calls[0].kwargs["content"] == "Quicksort is a divide-and-conquer sorting algorithm."
    assert isinstance(assistant_calls[0].kwargs["content"], str)


def test_chat_turn_accepts_str_only():
    turn = ChatTurn(role="assistant", content="Direct string content")
    assert isinstance(turn.content, str)
