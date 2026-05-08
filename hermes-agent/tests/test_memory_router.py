import pytest
from unittest.mock import patch, AsyncMock
from fastapi.testclient import TestClient
from main import app
from auth.firebase_jwt import get_current_user
from models.user import TokenData


def _override_auth():
    return TokenData(uid="test_uid", email="test@example.com")


@pytest.fixture
def client():
    app.dependency_overrides[get_current_user] = _override_auth
    yield TestClient(app)
    app.dependency_overrides.pop(get_current_user, None)


def test_get_memories_returns_200(client):
    mock_memories = []
    with patch("routers.memory.memory_service") as mock_svc:
        mock_svc.list_memories = AsyncMock(return_value=mock_memories)
        response = client.get("/api/v1/memory")
    assert response.status_code == 200
    assert response.json() == []


def test_delete_memory_returns_204(client):
    with patch("routers.memory.memory_service") as mock_svc:
        mock_svc.delete_memory = AsyncMock()
        response = client.delete("/api/v1/memory/mem123")
    assert response.status_code == 204
