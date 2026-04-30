import pytest
from unittest.mock import patch
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
    """Valid token + mocked Claude -> SSE response with data: chunks and [DONE]."""
    from models.user import TokenData
    from auth.firebase_jwt import get_current_user
    from main import app

    async def fake_stream(messages, assistant_name="Rocky"):
        yield "Hello"
        yield " world"

    app.dependency_overrides[get_current_user] = lambda: TokenData(uid="user123")
    try:
        with patch("routers.chat.stream_claude_response", side_effect=fake_stream):
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
        assert "data: [DONE]\n\n" in body
    finally:
        app.dependency_overrides.clear()
