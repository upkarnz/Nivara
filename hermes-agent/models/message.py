from enum import Enum
from pydantic import BaseModel


class Role(str, Enum):
    user = "user"
    assistant = "assistant"


class ChatMessage(BaseModel):
    role: Role
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    assistant_name: str = "Rocky"
    ai_model: str = "claude"
