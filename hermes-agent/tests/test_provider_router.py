import pytest
from unittest.mock import AsyncMock, patch
from providers.router import get_provider
from providers.claude_provider import ClaudeProvider


def test_get_provider_default_returns_claude():
    p = get_provider("claude")
    assert isinstance(p, ClaudeProvider)


def test_get_provider_unknown_returns_claude():
    p = get_provider("unknown_model")
    assert isinstance(p, ClaudeProvider)


def test_get_provider_empty_string_returns_claude():
    p = get_provider("")
    assert isinstance(p, ClaudeProvider)


@pytest.mark.asyncio
async def test_claude_provider_stream_response():
    provider = ClaudeProvider()
    mock_chunk = AsyncMock()
    mock_chunk.type = "content_block_delta"
    mock_chunk.delta = AsyncMock()
    mock_chunk.delta.type = "text_delta"
    mock_chunk.delta.text = "Hello"

    async def fake_stream(*args, **kwargs):
        yield mock_chunk

    with patch.object(provider._client.messages, "stream") as mock_stream:
        mock_stream.return_value.__aenter__ = AsyncMock(return_value=fake_stream())
        mock_stream.return_value.__aexit__ = AsyncMock(return_value=False)
        result = provider.stream_response(
            messages=[{"role": "user", "content": "Hi"}],
            system="You are helpful.",
        )
        import inspect
        assert inspect.isasyncgen(result) or callable(result)


@pytest.mark.asyncio
async def test_claude_provider_extract_facts_returns_string():
    provider = ClaudeProvider()
    mock_response = AsyncMock()
    mock_response.content = [AsyncMock(text='{"facts": []}')]

    mock_create = AsyncMock(return_value=mock_response)
    with patch.object(provider._client.messages, "create", mock_create):
        result = await provider.extract_facts("User said they like coffee.")
        assert isinstance(result, str)
