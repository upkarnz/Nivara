"""Fact extractor service: parses provider JSON output into MemoryCreate objects."""
import json
import logging
from typing import TYPE_CHECKING

from models.memory import MemoryCreate, MemoryType

if TYPE_CHECKING:
    from providers.base import AIProvider

logger = logging.getLogger(__name__)

CONFIDENCE_THRESHOLD = 0.6


class FactExtractor:
    """Extracts structured memory facts from raw conversation text via an AIProvider."""

    def __init__(self, provider: "AIProvider") -> None:
        self._provider = provider

    async def extract(self, conversation_text: str) -> list[MemoryCreate]:
        """Call provider.extract_facts(), parse JSON, filter by confidence.

        Returns:
            List of MemoryCreate objects with confidence >= CONFIDENCE_THRESHOLD.
            Returns empty list on any parse or provider error.
        """
        try:
            raw = await self._provider.extract_facts(conversation_text)
            data = json.loads(raw)
            facts = data.get("facts", [])
        except (json.JSONDecodeError, Exception) as e:
            logger.warning("Fact extraction failed: %s", e)
            return []

        results: list[MemoryCreate] = []
        for fact in facts:
            try:
                confidence = float(fact.get("confidence", 0))
                if confidence < CONFIDENCE_THRESHOLD:
                    continue
                memory_type = MemoryType(fact["memory_type"])
                results.append(
                    MemoryCreate(
                        content=fact["content"],
                        memory_type=memory_type,
                        confidence=confidence,
                    )
                )
            except (ValueError, KeyError) as e:
                logger.debug("Skipping invalid fact: %s", e)
                continue
        return results
