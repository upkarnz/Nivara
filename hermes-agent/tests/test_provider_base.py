import pytest
from providers.base import AIProvider


def test_ai_provider_is_class():
    import inspect
    assert inspect.isclass(AIProvider)


def test_ai_provider_has_stream_response():
    assert hasattr(AIProvider, "stream_response")


def test_ai_provider_has_extract_facts():
    assert hasattr(AIProvider, "extract_facts")


def test_concrete_provider_must_implement_both():
    """A class missing stream_response should raise TypeError at instantiation."""
    from providers.base import AIProvider

    class BadProvider(AIProvider):
        async def extract_facts(self, prompt: str) -> str:
            return ""

    with pytest.raises(TypeError):
        BadProvider()
