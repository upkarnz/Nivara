import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from services.obsidian_service import ObsidianService
from models.memory import Memory, MemoryType


def make_memory() -> Memory:
    return Memory(
        id="mem1",
        uid="user1",
        content="Loves hiking in Fiordland",
        memory_type=MemoryType.preference,
        confidence=0.9,
        created_at="2026-05-03T00:00:00Z",
        last_reinforced="2026-05-03T00:00:00Z",
        reinforcement_count=1,
    )


@pytest.fixture
def obsidian_service():
    with patch.dict("os.environ", {"OBSIDIAN_API_URL": "http://localhost:27123", "OBSIDIAN_API_KEY": "test"}):
        return ObsidianService()


def test_obsidian_service_instantiates(obsidian_service):
    assert obsidian_service is not None


@pytest.mark.asyncio
async def test_write_memory_sends_request(obsidian_service):
    mock_response = MagicMock()
    mock_response.status_code = 200

    with patch("httpx.AsyncClient.put", new_callable=AsyncMock) as mock_put:
        mock_put.return_value = mock_response
        await obsidian_service.write_memory(make_memory())
        mock_put.assert_called_once()
        call_kwargs = mock_put.call_args
        assert "Memories/user1" in str(call_kwargs)


@pytest.mark.asyncio
async def test_write_memory_silently_ignores_error(obsidian_service):
    with patch("httpx.AsyncClient.put", new_callable=AsyncMock) as mock_put:
        mock_put.side_effect = Exception("Connection refused")
        # Should not raise
        await obsidian_service.write_memory(make_memory())


@pytest.mark.asyncio
async def test_write_memory_skipped_when_no_url():
    with patch.dict("os.environ", {}, clear=True):
        service = ObsidianService()
        memory = make_memory()
        # Should complete without error even with no URL configured
        await service.write_memory(memory)
