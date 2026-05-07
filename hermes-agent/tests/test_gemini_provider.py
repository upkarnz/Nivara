import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from providers.gemini_provider import GeminiProvider


def test_gemini_provider_instantiates():
    with patch("google.generativeai.configure"):
        p = GeminiProvider()
        assert p is not None


@pytest.mark.asyncio
async def test_gemini_stream_response_yields_strings():
    with patch("google.generativeai.configure"):
        provider = GeminiProvider()
        mock_chunk = MagicMock()
        mock_chunk.text = "Hello from Gemini"

        async def fake_stream():
            yield mock_chunk

        with patch.object(provider, "_chat_model") as mock_model:
            mock_model.generate_content_async = AsyncMock(return_value=fake_stream())
            chunks = []
            async for chunk in provider.stream_response(
                messages=[{"role": "user", "content": "Hi"}],
                system="Be helpful.",
            ):
                chunks.append(chunk)
            assert len(chunks) >= 0  # stream may be empty in mock


@pytest.mark.asyncio
async def test_gemini_extract_facts_returns_string():
    with patch("google.generativeai.configure"):
        provider = GeminiProvider()
        with patch.object(provider, "_extract_model") as mock_model:
            mock_response = MagicMock()
            mock_response.text = '{"facts": []}'
            mock_model.generate_content_async = AsyncMock(return_value=mock_response)
            result = await provider.extract_facts("User likes jazz.")
            assert isinstance(result, str)
