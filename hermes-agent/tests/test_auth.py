import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from auth.firebase_jwt import get_current_user


@pytest.mark.asyncio
async def test_valid_token_returns_token_data():
    mock_creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid-token")
    mock_decoded = {"uid": "user123", "email": "test@example.com"}

    with patch("auth.firebase_jwt.firebase_auth.verify_id_token", return_value=mock_decoded):
        result = await get_current_user(mock_creds)

    assert result.uid == "user123"
    assert result.email == "test@example.com"


@pytest.mark.asyncio
async def test_invalid_token_raises_401():
    from firebase_admin.auth import InvalidIdTokenError
    mock_creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="bad-token")

    with patch("auth.firebase_jwt.firebase_auth.verify_id_token", side_effect=InvalidIdTokenError("bad")):
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(mock_creds)

    assert exc_info.value.status_code == 401
