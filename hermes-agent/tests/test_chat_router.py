import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


def test_chat_stream_requires_auth(client):
    """No auth header -> 403 Forbidden."""
    response = client.post(
        "/api/v1/chat/stream",
        json={"messages": [{"role": "user", "content": "Hi"}]},
    )
    assert response.status_code == 403


def test_chat_stream_invalid_token(client):
    """Invalid token -> 401 Unauthorized."""
    from firebase_admin.auth import InvalidIdTokenError

    with patch(
        "auth.firebase_jwt.firebase_auth.verify_id_token",
        side_effect=InvalidIdTokenError("bad"),
    ):
        response = client.post(
            "/api/v1/chat/stream",
            headers={"Authorization": "Bearer bad-token"},
            json={"messages": [{"role": "user", "content": "Hi"}]},
        )
    assert response.status_code == 401


def test_chat_stream_returns_sse(client):
    """Valid token + mocked provider -> SSE response with data: chunks."""
    from models.user import TokenData
    from auth.firebase_jwt import get_current_user
    from main import app

    async def fake_stream(messages, system):
        yield "Hello"
        yield " world"

    app.dependency_overrides[get_current_user] = lambda: TokenData(uid="user123")
    try:
        with patch("routers.chat.get_provider") as mock_get_provider:
            mock_provider = MagicMock()
            mock_provider.stream_response = MagicMock(return_value=fake_stream([], ""))
            mock_get_provider.return_value = mock_provider

            with patch("routers.chat.memory_service") as mock_mem:
                mock_mem.retrieve_memories = AsyncMock(return_value=[])
                mock_mem.save_memory = AsyncMock()

                response = client.post(
                    "/api/v1/chat/stream",
                    headers={"Authorization": "Bearer fake-token"},
                    json={"messages": [{"role": "user", "content": "Hi"}]},
                )

        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]
        body = response.text
        assert "data: Hello\n\n" in body
        assert "data:  world\n\n" in body
    finally:
        app.dependency_overrides.clear()


def test_chat_with_ai_model_gemini_routes_to_gemini(client):
    """When ai_model=gemini, provider router is called with gemini."""
    from models.user import TokenData
    from auth.firebase_jwt import get_current_user
    from main import app

    async def fake_stream():
        yield "Gemini response"

    app.dependency_overrides[get_current_user] = lambda: TokenData(uid="test_uid")
    try:
        with patch("routers.chat.get_provider") as mock_get_provider:
            mock_provider = MagicMock()
            mock_provider.stream_response = MagicMock(return_value=fake_stream())
            mock_get_provider.return_value = mock_provider

            with patch("routers.chat.memory_service") as mock_mem:
                mock_mem.retrieve_memories = AsyncMock(return_value=[])
                mock_mem.save_memory = AsyncMock()

                response = client.post(
                    "/api/v1/chat/stream",
                    json={
                        "messages": [{"role": "user", "content": "Hello"}],
                        "assistant_name": "Nivara",
                        "ai_model": "gemini",
                    },
                )
            mock_get_provider.assert_called_with("gemini")
            assert response.status_code == 200
    finally:
        app.dependency_overrides.clear()


def test_chat_injects_memories_into_system_prompt(client):
    """Memories retrieved from memory_service appear in system prompt."""
    from models.memory import Memory, MemoryType
    from models.user import TokenData
    from auth.firebase_jwt import get_current_user
    from main import app

    mock_memory = Memory(
        id="mem1",
        uid="test_uid",
        content="User loves Ethiopian food",
        memory_type=MemoryType.preference,
        confidence=0.9,
        created_at="2026-05-03T00:00:00Z",
        last_reinforced="2026-05-03T00:00:00Z",
        reinforcement_count=1,
    )

    async def fake_stream():
        yield "Response"

    app.dependency_overrides[get_current_user] = lambda: TokenData(uid="test_uid")
    try:
        with patch("routers.chat.get_provider") as mock_get_provider:
            mock_provider = MagicMock()
            captured_system = {}

            def capture_stream(messages, system):
                captured_system["value"] = system
                return fake_stream()

            mock_provider.stream_response = capture_stream
            mock_get_provider.return_value = mock_provider

            with patch("routers.chat.memory_service") as mock_mem:
                mock_mem.retrieve_memories = AsyncMock(return_value=[mock_memory])
                mock_mem.save_memory = AsyncMock()

                client.post(
                    "/api/v1/chat/stream",
                    json={
                        "messages": [{"role": "user", "content": "What food do I like?"}],
                        "assistant_name": "Nivara",
                        "ai_model": "claude",
                    },
                )
            assert "User loves Ethiopian food" in captured_system.get("value", "")
    finally:
        app.dependency_overrides.clear()
