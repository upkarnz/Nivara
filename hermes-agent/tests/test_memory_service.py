import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from services.memory_service import MemoryService
from models.memory import Memory, MemoryCreate, MemoryType


def make_memory(id: str = "mem1", content: str = "Loves hiking") -> Memory:
    return Memory(
        id=id,
        uid="user1",
        content=content,
        memory_type=MemoryType.preference,
        confidence=0.9,
        created_at="2026-05-03T00:00:00Z",
        last_reinforced="2026-05-03T00:00:00Z",
        reinforcement_count=1,
    )


@pytest.fixture
def service():
    mock_chroma = AsyncMock()
    mock_obsidian = AsyncMock()
    with patch("services.memory_service.firestore") as mock_firestore:
        mock_db = MagicMock()
        mock_firestore.client.return_value = mock_db
        svc = MemoryService(chroma=mock_chroma, obsidian=mock_obsidian, db=mock_db)
        return svc


@pytest.mark.asyncio
async def test_retrieve_memories_returns_list(service):
    service._chroma.query = AsyncMock(return_value=["mem1"])
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.id = "mem1"
    mock_doc.to_dict.return_value = {
        "uid": "user1",
        "content": "Loves hiking",
        "memory_type": "preference",
        "confidence": 0.9,
        "created_at": "2026-05-03T00:00:00Z",
        "last_reinforced": "2026-05-03T00:00:00Z",
        "reinforcement_count": 1,
    }

    async def fake_get(ref):
        return mock_doc

    service._get_doc = fake_get
    memories = await service.retrieve_memories("user1", "hiking outdoor")
    assert isinstance(memories, list)
    assert len(memories) == 1


@pytest.mark.asyncio
async def test_save_memory_writes_to_firestore_and_chroma(service):
    create = MemoryCreate(
        content="Loves hiking",
        memory_type=MemoryType.preference,
        confidence=0.9,
    )
    service._chroma.upsert = AsyncMock()
    service._obsidian.write_memory = AsyncMock()

    async def fake_to_thread(fn, *args, **kwargs):
        if not args and not kwargs:
            return []  # empty existing_docs (no duplicate)
        if args:
            try:
                fn(*args)
            except Exception:
                pass
        return None

    with patch("services.memory_service.asyncio.to_thread", side_effect=fake_to_thread):
        with patch("services.memory_service.asyncio.create_task"):
            saved = await service.save_memory("user1", create)
    assert saved.content == "Loves hiking"
    assert saved.uid == "user1"


@pytest.mark.asyncio
async def test_check_duplicate_returns_true_on_high_overlap(service):
    is_dup = service._is_duplicate("user loves hiking outdoors", "user loves hiking outdoors daily")
    assert is_dup is True


def test_check_duplicate_returns_false_on_low_overlap(service):
    is_dup = service._is_duplicate("Loves cats", "Prefers classical music")
    assert is_dup is False


@pytest.mark.asyncio
async def test_save_memory_reinforces_existing_duplicate(service):
    """save_memory updates existing doc when duplicate detected."""
    create = MemoryCreate(
        content="user loves hiking outdoors",
        memory_type=MemoryType.preference,
        confidence=0.95,
    )

    existing_data = {
        "uid": "user1",
        "content": "user loves hiking outdoors daily",
        "memory_type": "preference",
        "confidence": 0.8,
        "created_at": "2026-05-03T00:00:00Z",
        "last_reinforced": "2026-05-03T00:00:00Z",
        "reinforcement_count": 1,
        "source_turn": None,
    }
    mock_doc = MagicMock()
    mock_doc.id = "existing_id"
    mock_doc.to_dict.return_value = existing_data

    ref_mock = service._db.collection.return_value.document.return_value.collection.return_value
    ref_mock.where.return_value.stream.return_value = iter([mock_doc])
    ref_mock.document.return_value.update = MagicMock()

    call_count = 0

    async def fake_to_thread(fn, *args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # stream call (lambda returning list of existing docs)
            return [mock_doc]
        # subsequent calls (update)
        return None

    with patch("services.memory_service.asyncio.to_thread", side_effect=fake_to_thread):
        reinforced = await service.save_memory("user1", create)

    assert reinforced.id == "existing_id"
    assert reinforced.reinforcement_count == 2
    assert reinforced.confidence == 0.95


@pytest.mark.asyncio
async def test_delete_memory_calls_chroma_and_firestore(service):
    service._chroma.delete = AsyncMock()
    service._db.collection.return_value.document.return_value.collection.return_value.document.return_value.delete = MagicMock()

    async def fake_to_thread(fn, *args, **kwargs):
        if args:
            fn(*args)
        return None

    with patch("services.memory_service.asyncio.to_thread", side_effect=fake_to_thread):
        await service.delete_memory("user1", "mem1")
    service._chroma.delete.assert_called_once_with("mem1")
