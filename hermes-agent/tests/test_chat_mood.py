import json
import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


def _make_request(client):
    from models.user import TokenData
    from auth.firebase_jwt import get_current_user
    from main import app

    app.dependency_overrides[get_current_user] = lambda: TokenData(uid="user123")
    try:
        return client.post(
            "/api/v1/chat/stream",
            headers={"Authorization": "Bearer fake-token"},
            json={"messages": [{"role": "user", "content": "I'm feeling great today"}]},
        )
    finally:
        app.dependency_overrides.clear()


def test_mood_event_emitted_on_success(client):
    """After text stream, a __MOOD__ SSE event appears with the scored mood."""
    async def fake_stream(messages, system):
        yield "Hello"
        yield " there"

    with patch("routers.chat.get_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.stream_response = MagicMock(return_value=fake_stream([], ""))
        mock_provider.score_mood = AsyncMock(
            return_value='{"score": 5, "label": "happy"}'
        )
        mock_get_provider.return_value = mock_provider

        with patch("routers.chat.memory_service") as mock_mem:
            mock_mem.retrieve_memories = AsyncMock(return_value=[])
            mock_mem.save_memory = AsyncMock()

            response = _make_request(client)

    assert response.status_code == 200
    body = response.text
    assert "data: Hello\n\n" in body
    assert "data:  there\n\n" in body
    # Mood event must come after text chunks
    mood_marker = "data: __MOOD__"
    assert mood_marker in body
    assert body.index(mood_marker) > body.index("data:  there")
    # Parse the mood payload
    mood_line = [ln for ln in body.split("\n") if ln.startswith("data: __MOOD__")][0]
    payload = mood_line[len("data: __MOOD__"):]
    parsed = json.loads(payload)
    assert parsed == {"score": 5, "label": "happy"}


def test_no_mood_event_when_scorer_returns_none(client):
    """If score_mood returns invalid JSON (mood scorer returns None), no __MOOD__ event."""
    async def fake_stream(messages, system):
        yield "Hi"

    with patch("routers.chat.get_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.stream_response = MagicMock(return_value=fake_stream([], ""))
        # Returns garbage -> mood_scorer returns None
        mock_provider.score_mood = AsyncMock(return_value="not json")
        mock_get_provider.return_value = mock_provider

        with patch("routers.chat.memory_service") as mock_mem:
            mock_mem.retrieve_memories = AsyncMock(return_value=[])
            mock_mem.save_memory = AsyncMock()

            response = _make_request(client)

    assert response.status_code == 200
    assert "data: Hi\n\n" in response.text
    assert "__MOOD__" not in response.text


def test_no_mood_event_when_scorer_raises(client):
    """If provider.score_mood raises, no __MOOD__ event is emitted but stream completes."""
    async def fake_stream(messages, system):
        yield "Hey"

    with patch("routers.chat.get_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.stream_response = MagicMock(return_value=fake_stream([], ""))
        mock_provider.score_mood = AsyncMock(side_effect=RuntimeError("boom"))
        mock_get_provider.return_value = mock_provider

        with patch("routers.chat.memory_service") as mock_mem:
            mock_mem.retrieve_memories = AsyncMock(return_value=[])
            mock_mem.save_memory = AsyncMock()

            response = _make_request(client)

    assert response.status_code == 200
    assert "data: Hey\n\n" in response.text
    assert "__MOOD__" not in response.text
