"""Tests for FactExtractor service."""
import json
from unittest.mock import AsyncMock, MagicMock
import pytest
from models.memory import MemoryCreate, MemoryType
from services.fact_extractor import FactExtractor, CONFIDENCE_THRESHOLD


@pytest.fixture
def mock_provider():
    provider = MagicMock()
    provider.extract_facts = AsyncMock()
    return provider


@pytest.mark.asyncio
async def test_extract_returns_memory_creates(mock_provider):
    """extract() returns MemoryCreate list from valid JSON."""
    mock_provider.extract_facts.return_value = json.dumps({
        "facts": [
            {"content": "User likes coffee", "memory_type": "preference", "confidence": 0.9},
            {"content": "User works at Acme", "memory_type": "work_context", "confidence": 0.8},
        ]
    })
    extractor = FactExtractor(mock_provider)
    results = await extractor.extract("I like coffee and work at Acme")
    assert len(results) == 2
    assert all(isinstance(r, MemoryCreate) for r in results)
    assert results[0].content == "User likes coffee"
    assert results[0].memory_type == MemoryType.preference
    assert results[0].confidence == 0.9


@pytest.mark.asyncio
async def test_extract_filters_low_confidence(mock_provider):
    """extract() excludes facts with confidence < CONFIDENCE_THRESHOLD."""
    mock_provider.extract_facts.return_value = json.dumps({
        "facts": [
            {"content": "High confidence fact", "memory_type": "personal_fact", "confidence": 0.9},
            {"content": "Low confidence fact", "memory_type": "personal_fact", "confidence": 0.3},
            {"content": "At threshold", "memory_type": "personal_fact", "confidence": CONFIDENCE_THRESHOLD},
        ]
    })
    extractor = FactExtractor(mock_provider)
    results = await extractor.extract("some conversation")
    assert len(results) == 2
    assert all(r.confidence >= CONFIDENCE_THRESHOLD for r in results)


@pytest.mark.asyncio
async def test_extract_handles_invalid_json(mock_provider):
    """extract() returns empty list when provider returns invalid JSON."""
    mock_provider.extract_facts.return_value = "not valid json"
    extractor = FactExtractor(mock_provider)
    results = await extractor.extract("some conversation")
    assert results == []


@pytest.mark.asyncio
async def test_extract_handles_empty_facts(mock_provider):
    """extract() returns empty list when facts array is empty."""
    mock_provider.extract_facts.return_value = json.dumps({"facts": []})
    extractor = FactExtractor(mock_provider)
    results = await extractor.extract("some conversation")
    assert results == []


@pytest.mark.asyncio
async def test_extract_handles_invalid_memory_type(mock_provider):
    """extract() skips facts with invalid memory_type, returns valid ones."""
    mock_provider.extract_facts.return_value = json.dumps({
        "facts": [
            {"content": "Valid fact", "memory_type": "preference", "confidence": 0.8},
            {"content": "Invalid type fact", "memory_type": "nonexistent_type", "confidence": 0.9},
        ]
    })
    extractor = FactExtractor(mock_provider)
    results = await extractor.extract("some conversation")
    assert len(results) == 1
    assert results[0].content == "Valid fact"
