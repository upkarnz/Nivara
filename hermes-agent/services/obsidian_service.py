"""Obsidian REST API service for graph-layer memory persistence (fire-and-forget)."""
import os
import logging
import httpx
from models.memory import Memory

logger = logging.getLogger(__name__)

OBSIDIAN_TIMEOUT = 3.0


class ObsidianService:
    """Writes memory records to Obsidian via its Local REST API plugin.

    This is a fire-and-forget layer: all errors are silently swallowed and logged
    at debug level. Callers must never depend on this succeeding.
    """

    def __init__(self) -> None:
        self._api_url = os.environ.get("OBSIDIAN_API_URL", "")
        self._api_key = os.environ.get("OBSIDIAN_API_KEY", "")

    async def write_memory(self, memory: Memory) -> None:
        """Write a memory to Obsidian vault. No-op if OBSIDIAN_API_URL not set."""
        if not self._api_url:
            return
        path = f"Memories/{memory.uid}/{memory.memory_type.value}.md"
        content = (
            f"## {memory.content}\n\n"
            f"- type: {memory.memory_type.value}\n"
            f"- confidence: {memory.confidence}\n"
            f"- last_reinforced: {memory.last_reinforced}\n"
            f"- reinforcement_count: {memory.reinforcement_count}\n"
        )
        headers = {"Authorization": f"Bearer {self._api_key}"}
        try:
            async with httpx.AsyncClient(timeout=OBSIDIAN_TIMEOUT) as client:
                await client.put(
                    f"{self._api_url}/vault/{path}",
                    content=content.encode(),
                    headers=headers,
                )
        except Exception:
            logger.debug("Obsidian write skipped for memory %s", memory.id, exc_info=True)
