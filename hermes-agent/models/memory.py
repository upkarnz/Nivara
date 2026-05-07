# hermes-agent/models/memory.py
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class MemoryType(str, Enum):
    personal_fact = "personal_fact"
    preference = "preference"
    routine = "routine"
    relationship = "relationship"
    decision = "decision"
    goal = "goal"
    emotional_signal = "emotional_signal"
    work_context = "work_context"


class MemoryCreate(BaseModel):
    content: str
    memory_type: MemoryType
    confidence: float = Field(..., ge=0.0, le=1.0)
    source_turn: Optional[str] = None


class MemoryUpdate(BaseModel):
    content: Optional[str] = None
    confidence: Optional[float] = Field(None, ge=0.0, le=1.0)
    last_reinforced: Optional[str] = None
    reinforcement_count: Optional[int] = None


class Memory(BaseModel):
    id: str
    uid: str
    content: str
    memory_type: MemoryType
    confidence: float
    created_at: str
    last_reinforced: str
    reinforcement_count: int = 1
    source_turn: Optional[str] = None
