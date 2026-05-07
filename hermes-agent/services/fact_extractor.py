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
        except Exception:
            logger.exception("Provider extract_facts raised unexpectedly")
            return []

        try:
            data = json.loads(raw)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.warning("Fact extraction parse failed: %s", e)
            return []

        if not isinstance(data, dict):
            logger.warning("Unexpected JSON structure from provider: %s", type(data).__name__)
            return []

        facts = data.get("facts", [])
        if not isinstance(facts, list):
            logger.warning("'facts' field is not a list")
            return []

        results: list[MemoryCreate] = []
        for fact in facts:
            if not isinstance(fact, dict):
                logger.debug("Skipping non-dict fact: %s", type(fact).__name__)
                continue
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
