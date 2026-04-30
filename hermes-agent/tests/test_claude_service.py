import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from models.message import ChatMessage, Role


# Helper for async iteration in tests
async def async_iter(items):
    for item in items:
        yield item


@pytest.mark.asyncio
async def test_stream_claude_response_yields_chunks():
    """Test that stream_claude_response yields text chunks from Claude."""
    from services.claude_service import stream_claude_response

    mock_stream = AsyncMock()
    mock_stream.__aenter__ = AsyncMock(return_value=mock_stream)
    mock_stream.__aexit__ = AsyncMock(return_value=None)
    mock_stream.text_stream = async_iter(["Hello", ", ", "world", "!"])

    with patch("services.claude_service.client.messages.stream", return_value=mock_stream):
        messages = [ChatMessage(role=Role.user, content="Hi")]
        chunks = []
        async for chunk in stream_claude_response(messages, assistant_name="Rocky"):
            chunks.append(chunk)

    assert chunks == ["Hello", ", ", "world", "!"]


@pytest.mark.asyncio
async def test_stream_claude_response_uses_assistant_name():
    """Test that assistant name is included in system prompt."""
    from services.claude_service import stream_claude_response, client

    mock_stream = AsyncMock()
    mock_stream.__aenter__ = AsyncMock(return_value=mock_stream)
    mock_stream.__aexit__ = AsyncMock(return_value=None)
    mock_stream.text_stream = async_iter(["Hi"])

    with patch("services.claude_service.client.messages.stream", return_value=mock_stream) as mock_call:
        messages = [ChatMessage(role=Role.user, content="Hello")]
        async for _ in stream_claude_response(messages, assistant_name="Aria"):
            pass

    call_kwargs = mock_call.call_args.kwargs
    assert "Aria" in call_kwargs["system"]
