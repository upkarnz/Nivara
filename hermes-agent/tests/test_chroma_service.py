import pytest
from unittest.mock import MagicMock, patch, AsyncMock
from services.chroma_service import ChromaService
from models.memory import Memory, MemoryType


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
def chroma_service():
    with patch("chromadb.EphemeralClient") as mock_client_cls:
        mock_client = MagicMock()
        mock_collection = MagicMock()
        mock_client.get_or_create_collection.return_value = mock_collection
        mock_client_cls.return_value = mock_client
        service = ChromaService()
        service._collection = mock_collection
        return service


def test_chroma_service_instantiates(chroma_service):
    assert chroma_service is not None


@pytest.mark.asyncio
async def test_upsert_calls_collection(chroma_service):
    memory = make_memory()
    chroma_service._collection.upsert = MagicMock()

    await chroma_service.upsert(memory)

    chroma_service._collection.upsert.assert_called_once()
    call_kwargs = chroma_service._collection.upsert.call_args[1]
    assert call_kwargs["ids"] == ["mem1"]
    assert call_kwargs["documents"] == ["Loves hiking"]


@pytest.mark.asyncio
async def test_query_returns_memory_ids(chroma_service):
    chroma_service._collection.query = MagicMock(return_value={
        "ids": [["mem1", "mem2"]],
        "distances": [[0.1, 0.3]],
    })
    ids = await chroma_service.query("hiking outdoor activities", n_results=5)
    assert ids == ["mem1", "mem2"]


@pytest.mark.asyncio
async def test_delete_calls_collection(chroma_service):
    chroma_service._collection.delete = MagicMock()
    await chroma_service.delete("mem1")
    chroma_service._collection.delete.assert_called_once_with(ids=["mem1"])
