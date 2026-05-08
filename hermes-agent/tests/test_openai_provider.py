import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from providers.openai_provider import OpenAIProvider


def test_openai_provider_instantiates():
    with patch("openai.AsyncOpenAI"):
        p = OpenAIProvider()
        assert p is not None


@pytest.mark.asyncio
async def test_openai_stream_response_yields_strings():
    with patch("openai.AsyncOpenAI") as mock_client_cls:
        provider = OpenAIProvider()
        mock_chunk = MagicMock()
        mock_chunk.choices = [MagicMock()]
        mock_chunk.choices[0].delta.content = "Hello"

        async def fake_stream():
            yield mock_chunk

        mock_stream_ctx = MagicMock()
        mock_stream_ctx.__aenter__ = AsyncMock(return_value=fake_stream())
        mock_stream_ctx.__aexit__ = AsyncMock(return_value=False)
        provider._client.chat.completions.stream = MagicMock(return_value=mock_stream_ctx)

        chunks = []
        async for chunk in provider.stream_response(
            messages=[{"role": "user", "content": "Hi"}],
            system="Be helpful.",
        ):
            chunks.append(chunk)
        assert chunks == ["Hello"]


@pytest.mark.asyncio
async def test_openai_extract_facts_returns_string():
    with patch("openai.AsyncOpenAI"):
        provider = OpenAIProvider()
        mock_response = MagicMock()
        mock_response.choices[0].message.content = '{"facts": []}'
        provider._client.chat.completions.create = AsyncMock(return_value=mock_response)
        result = await provider.extract_facts("User likes hiking.")
        assert isinstance(result, str)
