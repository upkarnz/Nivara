# hermes-agent/tests/test_memory_models.py
import pytest
from pydantic import ValidationError
from models.memory import Memory, MemoryType, MemoryCreate, MemoryUpdate


def test_memory_type_values():
    assert MemoryType.personal_fact == "personal_fact"
    assert MemoryType.preference == "preference"
    assert MemoryType.routine == "routine"
    assert MemoryType.relationship == "relationship"
    assert MemoryType.decision == "decision"
    assert MemoryType.goal == "goal"
    assert MemoryType.emotional_signal == "emotional_signal"
    assert MemoryType.work_context == "work_context"


def test_memory_create_required_fields():
    m = MemoryCreate(
        content="Loves Ethiopian food",
        memory_type=MemoryType.preference,
        confidence=0.9,
    )
    assert m.content == "Loves Ethiopian food"
    assert m.memory_type == MemoryType.preference
    assert m.confidence == 0.9


def test_memory_confidence_range():
    with pytest.raises(ValidationError):
        MemoryCreate(content="x", memory_type=MemoryType.preference, confidence=1.5)
    with pytest.raises(ValidationError):
        MemoryCreate(content="x", memory_type=MemoryType.preference, confidence=-0.1)


def test_memory_has_timestamps():
    m = Memory(
        id="abc123",
        uid="user1",
        content="Works in Auckland",
        memory_type=MemoryType.work_context,
        confidence=0.8,
        created_at="2026-05-03T00:00:00Z",
        last_reinforced="2026-05-03T00:00:00Z",
        reinforcement_count=1,
    )
    assert m.id == "abc123"
    assert m.reinforcement_count == 1


def test_memory_update_partial():
    u = MemoryUpdate(confidence=0.95)
    assert u.confidence == 0.95
    assert u.content is None


def test_memory_update_confidence_bounds():
    with pytest.raises(ValidationError):
        MemoryUpdate(confidence=1.5)
    with pytest.raises(ValidationError):
        MemoryUpdate(confidence=-0.1)
