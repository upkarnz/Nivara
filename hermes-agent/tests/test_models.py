import pytest
from models.message import ChatMessage, ChatRequest, Role
from models.user import TokenData


def test_chat_message_role_enum():
    msg = ChatMessage(role=Role.user, content="hello")
    assert msg.role == "user"
    assert msg.content == "hello"


def test_chat_request_defaults():
    req = ChatRequest(messages=[ChatMessage(role=Role.user, content="hi")])
    assert req.assistant_name == "Rocky"
    assert req.ai_model == "claude"


def test_token_data_fields():
    td = TokenData(uid="abc123", email="u@example.com")
    assert td.uid == "abc123"
    assert td.email == "u@example.com"
