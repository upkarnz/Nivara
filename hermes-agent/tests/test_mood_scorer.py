import json
import pytest
from unittest.mock import AsyncMock, MagicMock
from services.mood_scorer import score_mood


class FakeProvider:
    async def score_mood(self, user_text: str) -> str:
        return json.dumps({"score": 3, "label": "neutral"})


class FakeProviderBadJson:
    async def score_mood(self, user_text: str) -> str:
        return "not json"


class FakeProviderOutOfRange:
    async def score_mood(self, user_text: str) -> str:
        return json.dumps({"score": 9, "label": "super"})


class FakeProviderRaises:
    async def score_mood(self, user_text: str) -> str:
        raise RuntimeError("provider error")


@pytest.mark.asyncio
async def test_score_mood_happy_path():
    result = await score_mood("I feel great today!", FakeProvider())
    assert result == {"score": 3, "label": "neutral"}


@pytest.mark.asyncio
async def test_score_mood_bad_json_returns_none():
    result = await score_mood("hello", FakeProviderBadJson())
    assert result is None


@pytest.mark.asyncio
async def test_score_mood_out_of_range_returns_none():
    result = await score_mood("hello", FakeProviderOutOfRange())
    assert result is None


@pytest.mark.asyncio
async def test_score_mood_provider_exception_returns_none():
    result = await score_mood("hello", FakeProviderRaises())
    assert result is None
