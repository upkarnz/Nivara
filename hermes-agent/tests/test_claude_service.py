import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from models.message import ChatMessage, Role


async def async_iter(items):
    for item in items:
        yield item


def make_mock_stream(chunks):
    """Create a mock client whose messages.stream(...) is an async context manager."""
    mock_stream_obj = MagicMock()
    mock_stream_obj.text_stream = async_iter(chunks)

    mock_cm = AsyncMock()
    mock_cm.__aenter__ = AsyncMock(return_value=mock_stream_obj)
    mock_cm.__aexit__ = AsyncMock(return_value=False)

    mock_client = MagicMock()
    mock_client.messages.stream.return_value = mock_cm
    return mock_client, mock_cm


@pytest.mark.asyncio
async def test_stream_claude_response_yields_chunks():
    from services.claude_service import stream_claude_response

    mock_client, _ = make_mock_stream(["Hello", ", ", "world", "!"])

    with patch("services.claude_service.get_client", return_value=mock_client):
        messages = [ChatMessage(role=Role.user, content="Hi")]
        chunks = []
        async for chunk in stream_claude_response(messages, assistant_name="Rocky"):
            chunks.append(chunk)

    assert chunks == ["Hello", ", ", "world", "!"]


@pytest.mark.asyncio
async def test_stream_claude_response_uses_assistant_name():
    from services.claude_service import stream_claude_response

    mock_client, _ = make_mock_stream(["Hi"])

    with patch("services.claude_service.get_client", return_value=mock_client):
        messages = [ChatMessage(role=Role.user, content="Hello")]
        async for _ in stream_claude_response(messages, assistant_name="Aria"):
            pass

    call_kwargs = mock_client.messages.stream.call_args.kwargs
    assert "Aria" in call_kwargs["system"]


@pytest.mark.asyncio
async def test_stream_claude_response_correct_payload():
    from services.claude_service import stream_claude_response

    mock_client, _ = make_mock_stream(["ok"])

    with patch("services.claude_service.get_client", return_value=mock_client):
        messages = [
            ChatMessage(role=Role.user, content="Hi"),
            ChatMessage(role=Role.assistant, content="Hello!"),
            ChatMessage(role=Role.user, content="How are you?"),
        ]
        async for _ in stream_claude_response(messages):
            pass

    call_kwargs = mock_client.messages.stream.call_args.kwargs
    assert call_kwargs["messages"] == [
        {"role": "user", "content": "Hi"},
        {"role": "assistant", "content": "Hello!"},
        {"role": "user", "content": "How are you?"},
    ]
    assert call_kwargs["model"] == "claude-sonnet-4-6"
    assert call_kwargs["max_tokens"] == 1024
