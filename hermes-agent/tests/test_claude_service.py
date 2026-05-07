import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from models.message import ChatMessage, Role


async def async_iter(items):
    for item in items:
        yield item


def make_mock_provider(chunks):
    """Create a mock provider that yields text chunks."""
    async def mock_stream_response(messages, system):
        for chunk in chunks:
            yield chunk

    mock_provider = MagicMock()
    mock_provider.stream_response = mock_stream_response
    return mock_provider


@pytest.mark.asyncio
async def test_stream_claude_response_yields_chunks():
    from services.claude_service import stream_claude_response

    mock_provider = make_mock_provider(["Hello", ", ", "world", "!"])

    with patch("services.claude_service.get_provider", return_value=mock_provider):
        messages = [ChatMessage(role=Role.user, content="Hi")]
        chunks = []
        async for chunk in stream_claude_response(messages, assistant_name="Rocky"):
            chunks.append(chunk)

    assert chunks == ["Hello", ", ", "world", "!"]


@pytest.mark.asyncio
async def test_stream_claude_response_uses_assistant_name():
    from services.claude_service import stream_claude_response

    called_with = {}

    async def mock_stream_response(messages, system):
        called_with["system"] = system
        yield "Hi"

    mock_provider = MagicMock()
    mock_provider.stream_response = mock_stream_response

    with patch("services.claude_service.get_provider", return_value=mock_provider):
        messages = [ChatMessage(role=Role.user, content="Hello")]
        async for _ in stream_claude_response(messages, assistant_name="Aria"):
            pass

    assert "Aria" in called_with["system"]


@pytest.mark.asyncio
async def test_stream_claude_response_correct_payload():
    from services.claude_service import stream_claude_response

    called_with = {}

    async def mock_stream_response(messages, system):
        called_with["messages"] = messages
        called_with["system"] = system
        yield "ok"

    mock_provider = MagicMock()
    mock_provider.stream_response = mock_stream_response

    with patch("services.claude_service.get_provider", return_value=mock_provider):
        messages = [
            ChatMessage(role=Role.user, content="Hi"),
            ChatMessage(role=Role.assistant, content="Hello!"),
            ChatMessage(role=Role.user, content="How are you?"),
        ]
        async for _ in stream_claude_response(messages):
            pass

    assert called_with["messages"] == [
        {"role": "user", "content": "Hi"},
        {"role": "assistant", "content": "Hello!"},
        {"role": "user", "content": "How are you?"},
    ]
