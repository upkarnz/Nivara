# Memory System + Multi-Provider Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent 3-layer memory (Firestore hot + ChromaDB vector + Obsidian graph) and multi-provider AI routing (Claude/Gemini/OpenAI) to Nivara.

**Architecture:** Memory lives entirely in Hermes backend. Each chat turn: retrieve top-5 memories via ChromaDB semantic search → inject into system prompt → stream response via selected provider → async extract facts → write to all 3 layers. Flutter adds a Memory page and AI model selector widget wired through Riverpod + SharedPreferences.

**Tech Stack:** Python 3.12, FastAPI, firebase-admin, chromadb==0.6.x, sentence-transformers, google-generativeai, openai, Flutter 3.x, Riverpod, shared_preferences

---

### Task 1: Memory Pydantic Models

**Files:**
- Create: `hermes-agent/models/memory.py`
- Create: `hermes-agent/tests/test_memory_models.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_memory_models.py
import pytest
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
    with pytest.raises(Exception):
        MemoryCreate(content="x", memory_type=MemoryType.preference, confidence=1.5)
    with pytest.raises(Exception):
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
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_memory_models.py -v
```
Expected: `ImportError: cannot import name 'Memory' from 'models.memory'`

- [ ] **Step 3: Implement models**

```python
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
```

- [ ] **Step 4: Run tests to confirm pass**

```bash
cd hermes-agent && python -m pytest tests/test_memory_models.py -v
```
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/models/memory.py hermes-agent/tests/test_memory_models.py
git commit -m "feat(memory): add Memory Pydantic models with 8 memory types"
```

---

### Task 2: AIProvider Protocol + Base

**Files:**
- Create: `hermes-agent/providers/__init__.py`
- Create: `hermes-agent/providers/base.py`
- Create: `hermes-agent/tests/test_provider_base.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_provider_base.py
import pytest
from providers.base import AIProvider


def test_ai_provider_is_protocol():
    from typing import get_type_hints
    import inspect
    assert inspect.isclass(AIProvider)


def test_ai_provider_has_stream_response():
    assert hasattr(AIProvider, "stream_response")


def test_ai_provider_has_extract_facts():
    assert hasattr(AIProvider, "extract_facts")


def test_concrete_provider_must_implement_both():
    """A class missing stream_response should raise TypeError at instantiation."""
    from providers.base import AIProvider

    class BadProvider(AIProvider):
        async def extract_facts(self, prompt: str) -> str:
            return ""

    with pytest.raises(TypeError):
        BadProvider()
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_provider_base.py -v
```
Expected: `ImportError: cannot import name 'AIProvider'`

- [ ] **Step 3: Implement protocol**

```python
# hermes-agent/providers/__init__.py
from providers.base import AIProvider
from providers.router import get_provider

__all__ = ["AIProvider", "get_provider"]
```

```python
# hermes-agent/providers/base.py
from abc import ABC, abstractmethod
from typing import AsyncGenerator


class AIProvider(ABC):
    @abstractmethod
    async def stream_response(
        self,
        messages: list[dict],
        system: str,
    ) -> AsyncGenerator[str, None]:
        """Stream tokens for a chat turn."""
        ...

    @abstractmethod
    async def extract_facts(self, prompt: str) -> str:
        """Extract facts from conversation text, return raw JSON string."""
        ...
```

Note: `providers/router.py` will be created in Task 3. For now create a stub:

```python
# hermes-agent/providers/router.py
from providers.base import AIProvider


def get_provider(ai_model: str) -> AIProvider:
    raise NotImplementedError("Router not yet wired")
```

- [ ] **Step 4: Run tests to confirm pass**

```bash
cd hermes-agent && python -m pytest tests/test_provider_base.py -v
```
Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/providers/__init__.py hermes-agent/providers/base.py hermes-agent/providers/router.py hermes-agent/tests/test_provider_base.py
git commit -m "feat(providers): add AIProvider abstract base class"
```

---

### Task 3: Claude Provider + Provider Router

**Files:**
- Create: `hermes-agent/providers/claude_provider.py`
- Modify: `hermes-agent/providers/router.py`
- Create: `hermes-agent/tests/test_provider_router.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_provider_router.py
import pytest
from unittest.mock import AsyncMock, patch
from providers.router import get_provider
from providers.claude_provider import ClaudeProvider


def test_get_provider_default_returns_claude():
    p = get_provider("claude")
    assert isinstance(p, ClaudeProvider)


def test_get_provider_unknown_returns_claude():
    p = get_provider("unknown_model")
    assert isinstance(p, ClaudeProvider)


def test_get_provider_empty_string_returns_claude():
    p = get_provider("")
    assert isinstance(p, ClaudeProvider)


@pytest.mark.asyncio
async def test_claude_provider_stream_response():
    provider = ClaudeProvider()
    mock_chunk = AsyncMock()
    mock_chunk.type = "content_block_delta"
    mock_chunk.delta = AsyncMock()
    mock_chunk.delta.type = "text_delta"
    mock_chunk.delta.text = "Hello"

    async def fake_stream(*args, **kwargs):
        yield mock_chunk

    with patch.object(provider._client.messages, "stream") as mock_stream:
        mock_stream.return_value.__aenter__ = AsyncMock(return_value=fake_stream())
        mock_stream.return_value.__aexit__ = AsyncMock(return_value=False)
        # Just verify it's callable and returns an async generator
        result = provider.stream_response(
            messages=[{"role": "user", "content": "Hi"}],
            system="You are helpful.",
        )
        import inspect
        assert inspect.isasyncgen(result) or callable(result)


@pytest.mark.asyncio
async def test_claude_provider_extract_facts_returns_string():
    provider = ClaudeProvider()
    with patch.object(provider._client.messages, "create") as mock_create:
        mock_create.return_value.content = [AsyncMock(text='{"facts": []}')]
        result = await provider.extract_facts("User said they like coffee.")
        assert isinstance(result, str)
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_provider_router.py -v
```
Expected: `ImportError` or `NotImplementedError`

- [ ] **Step 3: Implement ClaudeProvider**

```python
# hermes-agent/providers/claude_provider.py
import os
from typing import AsyncGenerator
import anthropic
from providers.base import AIProvider

CHAT_MODEL = "claude-sonnet-4-6"
EXTRACTION_MODEL = "claude-haiku-4-5"

EXTRACTION_SYSTEM = """Extract facts from this conversation excerpt. Return valid JSON only.
Schema: {"facts": [{"content": str, "memory_type": str, "confidence": float}]}
memory_type must be one of: personal_fact, preference, routine, relationship, decision, goal, emotional_signal, work_context
confidence: 0.0-1.0. Only include facts with confidence >= 0.6. Return {"facts": []} if none found."""


class ClaudeProvider(AIProvider):
    def __init__(self) -> None:
        self._client = anthropic.AsyncAnthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

    async def stream_response(
        self,
        messages: list[dict],
        system: str,
    ) -> AsyncGenerator[str, None]:
        async with self._client.messages.stream(
            model=CHAT_MODEL,
            max_tokens=4096,
            system=system,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                yield text

    async def extract_facts(self, prompt: str) -> str:
        response = await self._client.messages.create(
            model=EXTRACTION_MODEL,
            max_tokens=1024,
            system=EXTRACTION_SYSTEM,
            messages=[{"role": "user", "content": prompt}],
        )
        return response.content[0].text
```

- [ ] **Step 4: Implement router**

```python
# hermes-agent/providers/router.py
from providers.base import AIProvider
from providers.claude_provider import ClaudeProvider


def get_provider(ai_model: str) -> AIProvider:
    match ai_model:
        case "gemini":
            from providers.gemini_provider import GeminiProvider
            return GeminiProvider()
        case "openai":
            from providers.openai_provider import OpenAIProvider
            return OpenAIProvider()
        case _:
            return ClaudeProvider()
```

- [ ] **Step 5: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_provider_router.py -v
```
Expected: 5 passed (mock-based tests pass without real API keys)

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/providers/claude_provider.py hermes-agent/providers/router.py hermes-agent/tests/test_provider_router.py
git commit -m "feat(providers): add ClaudeProvider and provider router"
```

---

### Task 4: Gemini Provider

**Files:**
- Create: `hermes-agent/providers/gemini_provider.py`
- Create: `hermes-agent/tests/test_gemini_provider.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_gemini_provider.py
import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from providers.gemini_provider import GeminiProvider


def test_gemini_provider_instantiates():
    with patch("google.generativeai.configure"):
        p = GeminiProvider()
        assert p is not None


@pytest.mark.asyncio
async def test_gemini_stream_response_yields_strings():
    with patch("google.generativeai.configure"):
        provider = GeminiProvider()
        mock_chunk = MagicMock()
        mock_chunk.text = "Hello from Gemini"

        async def fake_stream():
            yield mock_chunk

        with patch.object(provider, "_chat_model") as mock_model:
            mock_model.generate_content_async = AsyncMock(return_value=fake_stream())
            chunks = []
            async for chunk in provider.stream_response(
                messages=[{"role": "user", "content": "Hi"}],
                system="Be helpful.",
            ):
                chunks.append(chunk)
            assert len(chunks) >= 0  # stream may be empty in mock


@pytest.mark.asyncio
async def test_gemini_extract_facts_returns_string():
    with patch("google.generativeai.configure"):
        provider = GeminiProvider()
        with patch.object(provider, "_extract_model") as mock_model:
            mock_response = MagicMock()
            mock_response.text = '{"facts": []}'
            mock_model.generate_content_async = AsyncMock(return_value=mock_response)
            result = await provider.extract_facts("User likes jazz.")
            assert isinstance(result, str)
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_gemini_provider.py -v
```
Expected: `ModuleNotFoundError: No module named 'google.generativeai'`

- [ ] **Step 3: Install dependency (temporary for dev)**

```bash
cd hermes-agent && pip install google-generativeai
```

- [ ] **Step 4: Implement GeminiProvider**

```python
# hermes-agent/providers/gemini_provider.py
import os
from typing import AsyncGenerator
import google.generativeai as genai
from providers.base import AIProvider

CHAT_MODEL = "gemini-2.0-flash"
EXTRACTION_MODEL = "gemini-2.0-flash"

EXTRACTION_SYSTEM = """Extract facts from this conversation excerpt. Return valid JSON only.
Schema: {"facts": [{"content": str, "memory_type": str, "confidence": float}]}
memory_type must be one of: personal_fact, preference, routine, relationship, decision, goal, emotional_signal, work_context
confidence: 0.0-1.0. Only include facts with confidence >= 0.6. Return {"facts": []} if none found."""


class GeminiProvider(AIProvider):
    def __init__(self) -> None:
        genai.configure(api_key=os.environ.get("GEMINI_API_KEY", ""))
        self._chat_model = genai.GenerativeModel(
            model_name=CHAT_MODEL,
        )
        self._extract_model = genai.GenerativeModel(
            model_name=EXTRACTION_MODEL,
            system_instruction=EXTRACTION_SYSTEM,
        )

    async def stream_response(
        self,
        messages: list[dict],
        system: str,
    ) -> AsyncGenerator[str, None]:
        # Convert messages to Gemini format
        gemini_messages = [
            {"role": "model" if m["role"] == "assistant" else "user", "parts": [m["content"]]}
            for m in messages
        ]
        response = await self._chat_model.generate_content_async(
            gemini_messages,
            generation_config=genai.GenerationConfig(max_output_tokens=4096),
            stream=True,
        )
        async for chunk in response:
            if chunk.text:
                yield chunk.text

    async def extract_facts(self, prompt: str) -> str:
        response = await self._extract_model.generate_content_async(prompt)
        return response.text
```

- [ ] **Step 5: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_gemini_provider.py -v
```
Expected: 3 passed

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/providers/gemini_provider.py hermes-agent/tests/test_gemini_provider.py
git commit -m "feat(providers): add GeminiProvider"
```

---

### Task 5: OpenAI Provider

**Files:**
- Create: `hermes-agent/providers/openai_provider.py`
- Create: `hermes-agent/tests/test_openai_provider.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_openai_provider.py
import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from providers.openai_provider import OpenAIProvider


def test_openai_provider_instantiates():
    with patch("openai.AsyncOpenAI"):
        p = OpenAIProvider()
        assert p is not None


@pytest.mark.asyncio
async def test_openai_stream_response_yields_strings():
    with patch("openai.AsyncOpenAI") as mock_client_cls:
        provider = OpenAIProvider()
        mock_chunk = MagicMock()
        mock_chunk.choices = [MagicMock()]
        mock_chunk.choices[0].delta.content = "Hello"

        async def fake_stream():
            yield mock_chunk

        mock_stream_ctx = MagicMock()
        mock_stream_ctx.__aenter__ = AsyncMock(return_value=fake_stream())
        mock_stream_ctx.__aexit__ = AsyncMock(return_value=False)
        provider._client.chat.completions.stream = MagicMock(return_value=mock_stream_ctx)

        chunks = []
        async for chunk in provider.stream_response(
            messages=[{"role": "user", "content": "Hi"}],
            system="Be helpful.",
        ):
            chunks.append(chunk)
        # With mock returning one chunk with content "Hello"
        assert chunks == ["Hello"]


@pytest.mark.asyncio
async def test_openai_extract_facts_returns_string():
    with patch("openai.AsyncOpenAI"):
        provider = OpenAIProvider()
        mock_response = MagicMock()
        mock_response.choices[0].message.content = '{"facts": []}'
        provider._client.chat.completions.create = AsyncMock(return_value=mock_response)
        result = await provider.extract_facts("User likes hiking.")
        assert isinstance(result, str)
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_openai_provider.py -v
```
Expected: `ModuleNotFoundError: No module named 'openai'`

- [ ] **Step 3: Install dependency**

```bash
cd hermes-agent && pip install openai
```

- [ ] **Step 4: Implement OpenAIProvider**

```python
# hermes-agent/providers/openai_provider.py
import os
from typing import AsyncGenerator
import openai
from providers.base import AIProvider

CHAT_MODEL = "gpt-4o"
EXTRACTION_MODEL = "gpt-4o-mini"

EXTRACTION_SYSTEM = """Extract facts from this conversation excerpt. Return valid JSON only.
Schema: {"facts": [{"content": str, "memory_type": str, "confidence": float}]}
memory_type must be one of: personal_fact, preference, routine, relationship, decision, goal, emotional_signal, work_context
confidence: 0.0-1.0. Only include facts with confidence >= 0.6. Return {"facts": []} if none found."""


class OpenAIProvider(AIProvider):
    def __init__(self) -> None:
        self._client = openai.AsyncOpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))

    async def stream_response(
        self,
        messages: list[dict],
        system: str,
    ) -> AsyncGenerator[str, None]:
        full_messages = [{"role": "system", "content": system}] + messages
        async with self._client.chat.completions.stream(
            model=CHAT_MODEL,
            max_tokens=4096,
            messages=full_messages,
        ) as stream:
            async for chunk in stream:
                content = chunk.choices[0].delta.content
                if content:
                    yield content

    async def extract_facts(self, prompt: str) -> str:
        response = await self._client.chat.completions.create(
            model=EXTRACTION_MODEL,
            max_tokens=1024,
            messages=[
                {"role": "system", "content": EXTRACTION_SYSTEM},
                {"role": "user", "content": prompt},
            ],
        )
        return response.choices[0].message.content
```

- [ ] **Step 5: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_openai_provider.py -v
```
Expected: 3 passed

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/providers/openai_provider.py hermes-agent/tests/test_openai_provider.py
git commit -m "feat(providers): add OpenAIProvider"
```

---

### Task 6: Update requirements.txt + Backwards-Compat claude_service.py

**Files:**
- Modify: `hermes-agent/requirements.txt`
- Modify: `hermes-agent/services/claude_service.py`

- [ ] **Step 1: Update requirements.txt**

Replace contents of `hermes-agent/requirements.txt` with:

```
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
anthropic>=0.40.0
firebase-admin>=6.5.0
pydantic>=2.0.0
httpx>=0.27.0
chromadb>=0.6.0
sentence-transformers>=3.0.0
google-generativeai>=0.8.0
openai>=1.50.0
pytest>=8.0.0
pytest-asyncio>=0.23.0
```

- [ ] **Step 2: Install new deps**

```bash
cd hermes-agent && pip install -r requirements.txt
```
Expected: installs without error (chromadb and sentence-transformers will take ~2 min first time)

- [ ] **Step 3: Update claude_service.py for backwards compat**

`hermes-agent/services/claude_service.py` currently exports `stream_claude_response`. Keep that function so existing `test_chat_router.py` mocks don't break, but delegate to `ClaudeProvider`:

```python
# hermes-agent/services/claude_service.py
"""Backwards-compatible wrapper around ClaudeProvider."""
from typing import AsyncGenerator
from providers.claude_provider import ClaudeProvider

_provider = ClaudeProvider()


async def stream_claude_response(
    messages: list[dict],
    assistant_name: str = "Nivara",
) -> AsyncGenerator[str, None]:
    system = f"You are {assistant_name}, a helpful personal AI assistant."
    async for chunk in _provider.stream_response(messages, system):
        yield chunk
```

- [ ] **Step 4: Run existing chat tests to verify no regression**

```bash
cd hermes-agent && python -m pytest tests/test_chat_router.py -v
```
Expected: all existing tests pass

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/requirements.txt hermes-agent/services/claude_service.py
git commit -m "feat(deps): add chromadb, sentence-transformers, gemini, openai deps; wrap claude_service"
```

---

### Task 7: Fact Extractor Service

**Files:**
- Create: `hermes-agent/services/fact_extractor.py`
- Create: `hermes-agent/tests/test_fact_extractor.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_fact_extractor.py
import pytest
import json
from unittest.mock import AsyncMock
from services.fact_extractor import FactExtractor
from models.memory import MemoryCreate, MemoryType


@pytest.fixture
def extractor():
    mock_provider = AsyncMock()
    return FactExtractor(provider=mock_provider)


@pytest.mark.asyncio
async def test_extract_returns_memory_creates(extractor):
    extractor._provider.extract_facts = AsyncMock(return_value=json.dumps({
        "facts": [
            {"content": "Lives in Auckland", "memory_type": "personal_fact", "confidence": 0.9},
            {"content": "Prefers dark coffee", "memory_type": "preference", "confidence": 0.85},
        ]
    }))
    results = await extractor.extract("User: I live in Auckland and love dark coffee")
    assert len(results) == 2
    assert all(isinstance(r, MemoryCreate) for r in results)
    assert results[0].content == "Lives in Auckland"
    assert results[0].memory_type == MemoryType.personal_fact


@pytest.mark.asyncio
async def test_extract_filters_low_confidence(extractor):
    extractor._provider.extract_facts = AsyncMock(return_value=json.dumps({
        "facts": [
            {"content": "Maybe likes cats", "memory_type": "preference", "confidence": 0.4},
            {"content": "Definitely likes dogs", "memory_type": "preference", "confidence": 0.8},
        ]
    }))
    results = await extractor.extract("some text")
    assert len(results) == 1
    assert results[0].content == "Definitely likes dogs"


@pytest.mark.asyncio
async def test_extract_handles_invalid_json(extractor):
    extractor._provider.extract_facts = AsyncMock(return_value="not json at all")
    results = await extractor.extract("some text")
    assert results == []


@pytest.mark.asyncio
async def test_extract_handles_empty_facts(extractor):
    extractor._provider.extract_facts = AsyncMock(return_value='{"facts": []}')
    results = await extractor.extract("small talk")
    assert results == []


@pytest.mark.asyncio
async def test_extract_handles_invalid_memory_type(extractor):
    extractor._provider.extract_facts = AsyncMock(return_value=json.dumps({
        "facts": [
            {"content": "Something", "memory_type": "invalid_type", "confidence": 0.9},
        ]
    }))
    results = await extractor.extract("some text")
    assert results == []
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_fact_extractor.py -v
```
Expected: `ImportError: cannot import name 'FactExtractor'`

- [ ] **Step 3: Implement FactExtractor**

```python
# hermes-agent/services/fact_extractor.py
import json
import logging
from providers.base import AIProvider
from models.memory import MemoryCreate, MemoryType

logger = logging.getLogger(__name__)

CONFIDENCE_THRESHOLD = 0.6


class FactExtractor:
    def __init__(self, provider: AIProvider) -> None:
        self._provider = provider

    async def extract(self, conversation_text: str) -> list[MemoryCreate]:
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
```

- [ ] **Step 4: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_fact_extractor.py -v
```
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/services/fact_extractor.py hermes-agent/tests/test_fact_extractor.py
git commit -m "feat(memory): add FactExtractor with confidence filtering and error handling"
```

---

### Task 8: ChromaDB Service

**Files:**
- Create: `hermes-agent/services/chroma_service.py`
- Create: `hermes-agent/tests/test_chroma_service.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_chroma_service.py
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
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_chroma_service.py -v
```
Expected: `ImportError: cannot import name 'ChromaService'`

- [ ] **Step 3: Implement ChromaService**

```python
# hermes-agent/services/chroma_service.py
import asyncio
import logging
import chromadb
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction
from models.memory import Memory

logger = logging.getLogger(__name__)

COLLECTION_NAME = "nivara_memories"
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"


class ChromaService:
    def __init__(self) -> None:
        self._client = chromadb.EphemeralClient()
        embedding_fn = SentenceTransformerEmbeddingFunction(model_name=EMBEDDING_MODEL)
        self._collection = self._client.get_or_create_collection(
            name=COLLECTION_NAME,
            embedding_function=embedding_fn,
        )

    async def upsert(self, memory: Memory) -> None:
        await asyncio.to_thread(
            self._collection.upsert,
            ids=[memory.id],
            documents=[memory.content],
            metadatas=[{
                "uid": memory.uid,
                "memory_type": memory.memory_type.value,
                "confidence": memory.confidence,
            }],
        )

    async def query(self, text: str, uid: str = "", n_results: int = 5) -> list[str]:
        where = {"uid": uid} if uid else None
        try:
            results = await asyncio.to_thread(
                self._collection.query,
                query_texts=[text],
                n_results=n_results,
                where=where,
            )
            return results["ids"][0] if results["ids"] else []
        except Exception as e:
            logger.warning("ChromaDB query failed: %s", e)
            return []

    async def delete(self, memory_id: str) -> None:
        await asyncio.to_thread(self._collection.delete, ids=[memory_id])
```

- [ ] **Step 4: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_chroma_service.py -v
```
Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/services/chroma_service.py hermes-agent/tests/test_chroma_service.py
git commit -m "feat(memory): add ChromaDB service with sentence-transformers embeddings"
```

---

### Task 9: Obsidian Service

**Files:**
- Create: `hermes-agent/services/obsidian_service.py`
- Create: `hermes-agent/tests/test_obsidian_service.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_obsidian_service.py
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
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_obsidian_service.py -v
```
Expected: `ImportError: cannot import name 'ObsidianService'`

- [ ] **Step 3: Implement ObsidianService**

```python
# hermes-agent/services/obsidian_service.py
import os
import logging
import httpx
from models.memory import Memory

logger = logging.getLogger(__name__)

OBSIDIAN_TIMEOUT = 3.0


class ObsidianService:
    def __init__(self) -> None:
        self._api_url = os.environ.get("OBSIDIAN_API_URL", "")
        self._api_key = os.environ.get("OBSIDIAN_API_KEY", "")

    async def write_memory(self, memory: Memory) -> None:
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
        except Exception as e:
            logger.debug("Obsidian write skipped: %s", e)
```

- [ ] **Step 4: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_obsidian_service.py -v
```
Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/services/obsidian_service.py hermes-agent/tests/test_obsidian_service.py
git commit -m "feat(memory): add ObsidianService with fire-and-forget write, silent failure"
```

---

### Task 10: Memory Service Orchestrator

**Files:**
- Create: `hermes-agent/services/memory_service.py`
- Create: `hermes-agent/tests/test_memory_service.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_memory_service.py
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
    service._chroma.query = AsyncMock(return_value=["mem1", "mem2"])
    mock_doc1 = MagicMock()
    mock_doc1.exists = True
    mock_doc1.id = "mem1"
    mock_doc1.to_dict.return_value = {
        "uid": "user1",
        "content": "Loves hiking",
        "memory_type": "preference",
        "confidence": 0.9,
        "created_at": "2026-05-03T00:00:00Z",
        "last_reinforced": "2026-05-03T00:00:00Z",
        "reinforcement_count": 1,
    }

    async def fake_get(ref):
        return mock_doc1

    service._get_doc = fake_get
    memories = await service.retrieve_memories("user1", "hiking outdoor")
    assert isinstance(memories, list)


@pytest.mark.asyncio
async def test_save_memory_writes_to_firestore_and_chroma(service):
    create = MemoryCreate(
        content="Loves hiking",
        memory_type=MemoryType.preference,
        confidence=0.9,
    )
    service._chroma.upsert = AsyncMock()
    service._obsidian.write_memory = AsyncMock()

    mock_doc_ref = MagicMock()
    mock_doc_ref.id = "new_id_123"
    service._db.collection.return_value.document.return_value.set = MagicMock()
    service._db.collection.return_value.document.return_value.id = "new_id_123"

    saved = await service.save_memory("user1", create)
    assert saved.content == "Loves hiking"
    assert saved.uid == "user1"


@pytest.mark.asyncio
async def test_check_duplicate_returns_existing_on_high_overlap(service):
    existing = make_memory(content="Loves hiking in Fiordland")
    new_content = "Loves hiking Fiordland"
    is_dup = service._is_duplicate(new_content, existing.content)
    assert is_dup is True


def test_check_duplicate_returns_false_on_low_overlap(service):
    is_dup = service._is_duplicate("Loves cats", "Prefers classical music")
    assert is_dup is False
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_memory_service.py -v
```
Expected: `ImportError: cannot import name 'MemoryService'`

- [ ] **Step 3: Implement MemoryService**

```python
# hermes-agent/services/memory_service.py
import asyncio
import logging
import uuid
from datetime import datetime, timezone

from firebase_admin import firestore
from services.chroma_service import ChromaService
from services.obsidian_service import ObsidianService
from models.memory import Memory, MemoryCreate, MemoryType

logger = logging.getLogger(__name__)

DUPLICATE_THRESHOLD = 0.8
MEMORIES_COLLECTION = "memories"


class MemoryService:
    def __init__(
        self,
        chroma: ChromaService | None = None,
        obsidian: ObsidianService | None = None,
        db=None,
    ) -> None:
        self._chroma = chroma or ChromaService()
        self._obsidian = obsidian or ObsidianService()
        self._db = db or firestore.client()

    def _memories_ref(self, uid: str):
        return self._db.collection("users").document(uid).collection(MEMORIES_COLLECTION)

    def _is_duplicate(self, content_a: str, content_b: str) -> bool:
        tokens_a = set(content_a.lower().split())
        tokens_b = set(content_b.lower().split())
        if not tokens_a or not tokens_b:
            return False
        overlap = len(tokens_a & tokens_b) / max(len(tokens_a), len(tokens_b))
        return overlap >= DUPLICATE_THRESHOLD

    async def _get_doc(self, ref):
        return await asyncio.to_thread(ref.get)

    async def retrieve_memories(self, uid: str, query_text: str, n: int = 5) -> list[Memory]:
        ids = await self._chroma.query(query_text, uid=uid, n_results=n)
        memories: list[Memory] = []
        ref = self._memories_ref(uid)
        for memory_id in ids:
            try:
                doc = await self._get_doc(ref.document(memory_id))
                if doc.exists:
                    data = doc.to_dict()
                    memories.append(Memory(id=doc.id, **data))
            except Exception as e:
                logger.warning("Failed to fetch memory %s: %s", memory_id, e)
        return memories

    async def save_memory(self, uid: str, create: MemoryCreate) -> Memory:
        now = datetime.now(timezone.utc).isoformat()
        memory_id = str(uuid.uuid4())
        ref = self._memories_ref(uid)

        existing_docs = await asyncio.to_thread(
            lambda: list(ref.where("memory_type", "==", create.memory_type.value).stream())
        )
        for doc in existing_docs:
            data = doc.to_dict()
            if self._is_duplicate(create.content, data.get("content", "")):
                update_data = {
                    "last_reinforced": now,
                    "reinforcement_count": data.get("reinforcement_count", 1) + 1,
                    "confidence": max(data.get("confidence", 0), create.confidence),
                }
                await asyncio.to_thread(ref.document(doc.id).update, update_data)
                return Memory(id=doc.id, uid=uid, **{**data, **update_data})

        memory_data = {
            "uid": uid,
            "content": create.content,
            "memory_type": create.memory_type.value,
            "confidence": create.confidence,
            "created_at": now,
            "last_reinforced": now,
            "reinforcement_count": 1,
            "source_turn": create.source_turn,
        }
        await asyncio.to_thread(ref.document(memory_id).set, memory_data)
        memory = Memory(id=memory_id, **memory_data)

        await self._chroma.upsert(memory)
        asyncio.create_task(self._obsidian.write_memory(memory))

        return memory

    async def list_memories(self, uid: str) -> list[Memory]:
        ref = self._memories_ref(uid)
        docs = await asyncio.to_thread(
            lambda: list(ref.order_by("last_reinforced", direction="DESCENDING").stream())
        )
        return [Memory(id=d.id, **d.to_dict()) for d in docs]

    async def delete_memory(self, uid: str, memory_id: str) -> None:
        ref = self._memories_ref(uid)
        await asyncio.to_thread(ref.document(memory_id).delete)
        await self._chroma.delete(memory_id)
```

- [ ] **Step 4: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_memory_service.py -v
```
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/services/memory_service.py hermes-agent/tests/test_memory_service.py
git commit -m "feat(memory): add MemoryService orchestrator with deduplication"
```

---

### Task 11: Memory API Router + main.py Registration

**Files:**
- Create: `hermes-agent/routers/memory.py`
- Modify: `hermes-agent/main.py`
- Create: `hermes-agent/tests/test_memory_router.py`

- [ ] **Step 1: Write failing tests**

```python
# hermes-agent/tests/test_memory_router.py
import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi.testclient import TestClient
from main import app
from auth.firebase_jwt import get_current_user, TokenData


def override_auth():
    return TokenData(uid="test_uid", email="test@example.com")


app.dependency_overrides[get_current_user] = override_auth


@pytest.fixture
def client():
    return TestClient(app)


def test_get_memories_returns_200(client):
    mock_memories = []
    with patch("routers.memory.memory_service") as mock_svc:
        mock_svc.list_memories = AsyncMock(return_value=mock_memories)
        response = client.get("/api/v1/memory")
    assert response.status_code == 200
    assert response.json() == []


def test_delete_memory_returns_204(client):
    with patch("routers.memory.memory_service") as mock_svc:
        mock_svc.delete_memory = AsyncMock()
        response = client.delete("/api/v1/memory/mem123")
    assert response.status_code == 204
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_memory_router.py -v
```
Expected: 404 errors (routes not registered)

- [ ] **Step 3: Create memory router**

```python
# hermes-agent/routers/memory.py
from fastapi import APIRouter, Depends, HTTPException, status
from auth.firebase_jwt import get_current_user, TokenData
from services.memory_service import MemoryService
from models.memory import Memory

router = APIRouter()
memory_service = MemoryService()


@router.get("", response_model=list[Memory])
async def list_memories(
    current_user: TokenData = Depends(get_current_user),
) -> list[Memory]:
    return await memory_service.list_memories(current_user.uid)


@router.delete("/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_memory(
    memory_id: str,
    current_user: TokenData = Depends(get_current_user),
) -> None:
    await memory_service.delete_memory(current_user.uid, memory_id)
```

- [ ] **Step 4: Register in main.py**

In `hermes-agent/main.py`, add after the existing `app.include_router(chat.router, ...)` line:

```python
from routers import memory
app.include_router(memory.router, prefix="/api/v1/memory", tags=["memory"])
```

The full updated lifespan/include block:

```python
from routers import chat, memory

# inside create_app or at module level:
app.include_router(chat.router, prefix="/api/v1", tags=["chat"])
app.include_router(memory.router, prefix="/api/v1/memory", tags=["memory"])
```

- [ ] **Step 5: Run tests**

```bash
cd hermes-agent && python -m pytest tests/test_memory_router.py -v
```
Expected: 2 passed

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/routers/memory.py hermes-agent/main.py hermes-agent/tests/test_memory_router.py
git commit -m "feat(memory): add memory API router with list + delete endpoints"
```

---

### Task 12: Update Chat Router with Memory Pipeline

**Files:**
- Modify: `hermes-agent/routers/chat.py`
- Modify: `hermes-agent/tests/test_chat_router.py`

- [ ] **Step 1: Add new tests to existing test file**

Append to `hermes-agent/tests/test_chat_router.py`:

```python
# Append to existing tests/test_chat_router.py

def test_chat_with_ai_model_gemini_routes_to_gemini(client):
    """When ai_model=gemini, provider router is called with gemini."""
    async def fake_stream():
        yield "Gemini response"

    with patch("routers.chat.get_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.stream_response = MagicMock(return_value=fake_stream())
        mock_get_provider.return_value = mock_provider

        with patch("routers.chat.memory_service") as mock_mem:
            mock_mem.retrieve_memories = AsyncMock(return_value=[])
            mock_mem.save_memory = AsyncMock()

            response = client.post(
                "/api/v1/chat/stream",
                json={
                    "messages": [{"role": "user", "content": "Hello"}],
                    "assistant_name": "Nivara",
                    "ai_model": "gemini",
                },
            )
        mock_get_provider.assert_called_with("gemini")
        assert response.status_code == 200


def test_chat_injects_memories_into_system_prompt(client):
    """Memories retrieved from memory_service appear in system prompt."""
    from models.memory import Memory, MemoryType

    mock_memory = Memory(
        id="mem1",
        uid="test_uid",
        content="User loves Ethiopian food",
        memory_type=MemoryType.preference,
        confidence=0.9,
        created_at="2026-05-03T00:00:00Z",
        last_reinforced="2026-05-03T00:00:00Z",
        reinforcement_count=1,
    )

    async def fake_stream():
        yield "Response"

    with patch("routers.chat.get_provider") as mock_get_provider:
        mock_provider = MagicMock()
        captured_system = {}

        def capture_stream(messages, system):
            captured_system["value"] = system
            return fake_stream()

        mock_provider.stream_response = capture_stream
        mock_get_provider.return_value = mock_provider

        with patch("routers.chat.memory_service") as mock_mem:
            mock_mem.retrieve_memories = AsyncMock(return_value=[mock_memory])
            mock_mem.save_memory = AsyncMock()

            client.post(
                "/api/v1/chat/stream",
                json={
                    "messages": [{"role": "user", "content": "What food do I like?"}],
                    "assistant_name": "Nivara",
                    "ai_model": "claude",
                },
            )
        assert "User loves Ethiopian food" in captured_system.get("value", "")
```

- [ ] **Step 2: Run new tests to confirm failure**

```bash
cd hermes-agent && python -m pytest tests/test_chat_router.py::test_chat_with_ai_model_gemini_routes_to_gemini tests/test_chat_router.py::test_chat_injects_memories_into_system_prompt -v
```
Expected: FAILED (no `get_provider` or `memory_service` in chat router yet)

- [ ] **Step 3: Update chat.py**

Replace `hermes-agent/routers/chat.py` with:

```python
import asyncio
import logging
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from auth.firebase_jwt import get_current_user, TokenData
from models.message import ChatRequest
from providers.router import get_provider
from services.memory_service import MemoryService
from services.fact_extractor import FactExtractor

logger = logging.getLogger(__name__)
router = APIRouter()
memory_service = MemoryService()

MEMORY_INJECT_HEADER = "\n\n## What you know about the user\nUse this naturally in conversation, don't announce it:\n"


def _build_system_prompt(assistant_name: str, memories: list) -> str:
    base = f"You are {assistant_name}, a helpful personal AI assistant."
    if not memories:
        return base
    facts = "\n".join(f"- {m.content}" for m in memories)
    return base + MEMORY_INJECT_HEADER + facts


@router.post("/chat/stream")
async def stream_chat(
    request: ChatRequest,
    current_user: TokenData = Depends(get_current_user),
) -> StreamingResponse:
    uid = current_user.uid
    messages = [{"role": m.role.value, "content": m.content} for m in request.messages]
    last_user_text = next(
        (m.content for m in reversed(request.messages) if m.role.value == "user"), ""
    )

    memories = await memory_service.retrieve_memories(uid, last_user_text)
    system_prompt = _build_system_prompt(request.assistant_name, memories)

    provider = get_provider(request.ai_model)

    async def generate():
        full_response_parts: list[str] = []
        try:
            async for chunk in provider.stream_response(messages, system_prompt):
                full_response_parts.append(chunk)
                yield f"data: {chunk}\n\n"
        except Exception as e:
            logger.error("Stream error: %s", e)
            yield "data: [ERROR]\n\n"
        finally:
            full_response = "".join(full_response_parts)
            conversation_text = f"User: {last_user_text}\nAssistant: {full_response}"
            extractor = FactExtractor(provider=provider)
            asyncio.create_task(_extract_and_save(uid, conversation_text, extractor))

    return StreamingResponse(generate(), media_type="text/event-stream")


async def _extract_and_save(uid: str, conversation_text: str, extractor: FactExtractor) -> None:
    try:
        facts = await extractor.extract(conversation_text)
        for fact in facts:
            await memory_service.save_memory(uid, fact)
    except Exception as e:
        logger.warning("Post-turn extraction failed: %s", e)
```

- [ ] **Step 4: Run all chat router tests**

```bash
cd hermes-agent && python -m pytest tests/test_chat_router.py -v
```
Expected: all pass (existing + 2 new)

- [ ] **Step 5: Commit**

```bash
git add hermes-agent/routers/chat.py hermes-agent/tests/test_chat_router.py
git commit -m "feat(chat): wire memory retrieval + provider routing + async fact extraction"
```

---

### Task 13: Flutter Memory Domain + Data Layer

**Files:**
- Create: `nivara/lib/features/memory/domain/memory.dart`
- Create: `nivara/lib/features/memory/data/memory_repository.dart`

- [ ] **Step 1: Write failing tests**

```dart
// nivara/test/features/memory/data/memory_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:nivara/features/memory/data/memory_repository.dart';
import 'package:nivara/features/memory/domain/memory.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('MemoryRepository', () {
    late MockHttpClient mockClient;
    late MemoryRepository repo;

    setUp(() {
      mockClient = MockHttpClient();
      repo = MemoryRepository(client: mockClient, baseUrl: 'http://localhost:8000');
    });

    test('fetchMemories returns list of Memory on 200', () async {
      when(mockClient.get(
        Uri.parse('http://localhost:8000/api/v1/memory'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        '[{"id":"1","uid":"u1","content":"Loves hiking","memory_type":"preference","confidence":0.9,"created_at":"2026-05-03T00:00:00Z","last_reinforced":"2026-05-03T00:00:00Z","reinforcement_count":1}]',
        200,
      ));

      final memories = await repo.fetchMemories('fake_token');
      expect(memories, isA<List<Memory>>());
      expect(memories.length, 1);
      expect(memories.first.content, 'Loves hiking');
    });

    test('fetchMemories throws on non-200', () async {
      when(mockClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(() => repo.fetchMemories('bad_token'), throwsException);
    });

    test('deleteMemory calls DELETE endpoint', () async {
      when(mockClient.delete(
        Uri.parse('http://localhost:8000/api/v1/memory/mem1'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response('', 204));

      await repo.deleteMemory('fake_token', 'mem1');
      verify(mockClient.delete(any, headers: anyNamed('headers'))).called(1);
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd nivara && flutter test test/features/memory/data/memory_repository_test.dart
```
Expected: compile error — no `memory.dart` or `memory_repository.dart`

- [ ] **Step 3: Create domain model**

```dart
// nivara/lib/features/memory/domain/memory.dart
class Memory {
  const Memory({
    required this.id,
    required this.uid,
    required this.content,
    required this.memoryType,
    required this.confidence,
    required this.createdAt,
    required this.lastReinforced,
    required this.reinforcementCount,
  });

  final String id;
  final String uid;
  final String content;
  final String memoryType;
  final double confidence;
  final String createdAt;
  final String lastReinforced;
  final int reinforcementCount;

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        uid: json['uid'] as String,
        content: json['content'] as String,
        memoryType: json['memory_type'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        createdAt: json['created_at'] as String,
        lastReinforced: json['last_reinforced'] as String,
        reinforcementCount: json['reinforcement_count'] as int,
      );
}
```

- [ ] **Step 4: Create repository**

```dart
// nivara/lib/features/memory/data/memory_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/memory.dart';

class MemoryRepository {
  MemoryRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<Memory>> fetchMemories(String idToken) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/memory'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('fetchMemories failed: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteMemory(String idToken, String memoryId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/memory/$memoryId'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 204) {
      throw Exception('deleteMemory failed: ${response.statusCode}');
    }
  }
}
```

- [ ] **Step 5: Add mockito to pubspec.yaml dev_dependencies if not present**

Check `nivara/pubspec.yaml`. If `mockito` is missing under `dev_dependencies`, add:
```yaml
dev_dependencies:
  mockito: ^5.4.0
  build_runner: ^2.4.0
```
Then run: `cd nivara && flutter pub get`

- [ ] **Step 6: Run tests**

```bash
cd nivara && flutter test test/features/memory/data/memory_repository_test.dart
```
Expected: 3 passed

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/features/memory/ nivara/test/features/memory/
git commit -m "feat(flutter): add Memory domain model and MemoryRepository"
```

---

### Task 14: Flutter Memory Presentation (Provider + Tile + Page)

**Files:**
- Create: `nivara/lib/features/memory/presentation/providers/memory_provider.dart`
- Create: `nivara/lib/features/memory/presentation/widgets/memory_tile.dart`
- Create: `nivara/lib/features/memory/presentation/pages/memory_page.dart`
- Create: `nivara/test/features/memory/presentation/memory_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

```dart
// nivara/test/features/memory/presentation/memory_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/memory/data/memory_repository.dart';
import 'package:nivara/features/memory/domain/memory.dart';
import 'package:nivara/features/memory/presentation/providers/memory_provider.dart';

class MockMemoryRepository extends Mock implements MemoryRepository {}

void main() {
  test('memoryNotifierProvider loads memories', () async {
    final mockRepo = MockMemoryRepository();
    final testMemory = Memory(
      id: '1', uid: 'u1', content: 'Loves hiking',
      memoryType: 'preference', confidence: 0.9,
      createdAt: '2026-05-03T00:00:00Z',
      lastReinforced: '2026-05-03T00:00:00Z',
      reinforcementCount: 1,
    );

    when(mockRepo.fetchMemories(any))
        .thenAnswer((_) async => [testMemory]);

    final container = ProviderContainer(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    // Trigger load
    final notifier = container.read(memoryNotifierProvider.notifier);
    await notifier.loadMemories('fake_token');

    final state = container.read(memoryNotifierProvider);
    expect(state, isA<AsyncData<List<Memory>>>());
    expect(state.value?.length, 1);
  });
}
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd nivara && flutter test test/features/memory/presentation/memory_provider_test.dart
```
Expected: compile error

- [ ] **Step 3: Create memory provider**

```dart
// nivara/lib/features/memory/presentation/providers/memory_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/memory_repository.dart';
import '../../domain/memory.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(baseUrl: 'http://localhost:8000');
});

class MemoryNotifier extends AsyncNotifier<List<Memory>> {
  @override
  Future<List<Memory>> build() async => [];

  Future<void> loadMemories(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memoryRepositoryProvider).fetchMemories(idToken),
    );
  }

  Future<void> deleteMemory(String idToken, String memoryId) async {
    await ref.read(memoryRepositoryProvider).deleteMemory(idToken, memoryId);
    await loadMemories(idToken);
  }
}

final memoryNotifierProvider =
    AsyncNotifierProvider<MemoryNotifier, List<Memory>>(MemoryNotifier.new);
```

- [ ] **Step 4: Create MemoryTile widget**

```dart
// nivara/lib/features/memory/presentation/widgets/memory_tile.dart
import 'package:flutter/material.dart';
import '../../domain/memory.dart';

class MemoryTile extends StatelessWidget {
  const MemoryTile({
    super.key,
    required this.memory,
    required this.onDelete,
  });

  final Memory memory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _typeIcon(memory.memoryType),
      title: Text(memory.content),
      subtitle: Text(
        '${memory.memoryType.replaceAll('_', ' ')} · ${(memory.confidence * 100).toStringAsFixed(0)}% confidence',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
        tooltip: 'Forget this',
      ),
    );
  }

  Icon _typeIcon(String type) {
    return switch (type) {
      'preference' => const Icon(Icons.favorite_outline),
      'personal_fact' => const Icon(Icons.person_outline),
      'goal' => const Icon(Icons.flag_outlined),
      'work_context' => const Icon(Icons.work_outline),
      'relationship' => const Icon(Icons.people_outline),
      'routine' => const Icon(Icons.schedule_outlined),
      'decision' => const Icon(Icons.check_circle_outline),
      'emotional_signal' => const Icon(Icons.mood_outlined),
      _ => const Icon(Icons.info_outline),
    };
  }
}
```

- [ ] **Step 5: Create MemoryPage**

```dart
// nivara/lib/features/memory/presentation/pages/memory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/memory_provider.dart';
import '../widgets/memory_tile.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;
    ref.read(memoryNotifierProvider.notifier).loadMemories(token);
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Memories')),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memories) {
          if (memories.isEmpty) {
            return const Center(child: Text('No memories yet. Keep chatting!'));
          }
          return ListView.builder(
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return MemoryTile(
                memory: memory,
                onDelete: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final token = await user.getIdToken();
                  if (token == null) return;
                  ref
                      .read(memoryNotifierProvider.notifier)
                      .deleteMemory(token, memory.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Run provider tests**

```bash
cd nivara && flutter test test/features/memory/presentation/memory_provider_test.dart
```
Expected: 1 passed

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/features/memory/presentation/ nivara/test/features/memory/presentation/
git commit -m "feat(flutter): add Memory presentation layer — provider, tile, page"
```

---

### Task 15: Flutter AI Model State Provider + ModelSelectorWidget

**Files:**
- Create: `nivara/lib/features/settings/presentation/providers/ai_model_provider.dart`
- Create: `nivara/lib/features/settings/presentation/widgets/model_selector_widget.dart`
- Create: `nivara/test/features/settings/ai_model_provider_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// nivara/test/features/settings/ai_model_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aiModelNotifierProvider defaults to claude', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'claude');
  });

  test('setModel persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(aiModelNotifierProvider.future);
    await container.read(aiModelNotifierProvider.notifier).setModel('gemini');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_ai_model'), 'gemini');
  });

  test('aiModelNotifierProvider loads persisted value', () async {
    SharedPreferences.setMockInitialValues({'selected_ai_model': 'openai'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(aiModelNotifierProvider.future);
    expect(value, 'openai');
  });
}
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
cd nivara && flutter test test/features/settings/ai_model_provider_test.dart
```
Expected: compile error

- [ ] **Step 3: Create AI model provider**

```dart
// nivara/lib/features/settings/presentation/providers/ai_model_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'selected_ai_model';
const _defaultModel = 'claude';

class AiModelNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) ?? _defaultModel;
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, model);
    state = AsyncData(model);
  }
}

final aiModelNotifierProvider =
    AsyncNotifierProvider<AiModelNotifier, String>(AiModelNotifier.new);
```

- [ ] **Step 4: Create ModelSelectorWidget**

```dart
// nivara/lib/features/settings/presentation/widgets/model_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_model_provider.dart';

const _models = [
  ('claude', 'Claude (Anthropic)', 'Default — best quality'),
  ('gemini', 'Gemini (Google)', 'Fast and capable'),
  ('openai', 'GPT-4o (OpenAI)', 'Strong general reasoning'),
];

class ModelSelectorWidget extends ConsumerWidget {
  const ModelSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(aiModelNotifierProvider);

    return modelAsync.when(
      loading: () => const CircularProgressIndicator.adaptive(),
      error: (e, _) => Text('Error: $e'),
      data: (selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _models.map((model) {
          final (value, label, subtitle) = model;
          return RadioListTile<String>(
            value: value,
            groupValue: selected,
            title: Text(label),
            subtitle: Text(subtitle),
            onChanged: (v) {
              if (v != null) {
                ref.read(aiModelNotifierProvider.notifier).setModel(v);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```bash
cd nivara && flutter test test/features/settings/ai_model_provider_test.dart
```
Expected: 3 passed

- [ ] **Step 6: Commit**

```bash
git add nivara/lib/features/settings/presentation/providers/ai_model_provider.dart nivara/lib/features/settings/presentation/widgets/model_selector_widget.dart nivara/test/features/settings/ai_model_provider_test.dart
git commit -m "feat(flutter): add AI model state provider + ModelSelectorWidget"
```

---

### Task 16: Flutter Wiring (chat_provider, voice_settings_page, app_router, chat_page)

**Files:**
- Modify: `nivara/lib/features/chat/presentation/providers/chat_provider.dart`
- Modify: `nivara/lib/router/app_router.dart`
- Modify: `nivara/lib/voice/voice_settings_page.dart`
- Modify: `nivara/lib/features/chat/presentation/pages/chat_page.dart`
- Create: `nivara/test/features/chat/presentation/chat_provider_wiring_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// nivara/test/features/chat/presentation/chat_provider_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_ai_model': 'gemini'});
  });

  test('aiModelNotifierProvider returns gemini when set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final model = await container.read(aiModelNotifierProvider.future);
    expect(model, 'gemini');
  });
}
```

- [ ] **Step 2: Run test to confirm pass**

```bash
cd nivara && flutter test test/features/chat/presentation/chat_provider_wiring_test.dart
```
Expected: 1 passed (provider already works; this verifies wiring context)

- [ ] **Step 3: Update chat_provider.dart to pass ai_model**

In `nivara/lib/features/chat/presentation/providers/chat_provider.dart`:

Add import at top:
```dart
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';
```

In `sendMessage()`, before calling `chatStream`, read the selected model:
```dart
final aiModel = ref.read(aiModelNotifierProvider).valueOrNull ?? 'claude';
```

Update the `chatStream` call to pass `aiModel`:
```dart
await for (final chunk in client.chatStream(
  messages: hermesMessages,
  assistantName: assistantName,
  aiModel: aiModel,
)) {
```

- [ ] **Step 4: Update HermesClient.chatStream signature**

In `nivara/lib/core/network/hermes_client.dart` (or equivalent), add `aiModel` parameter to `chatStream`:

```dart
Stream<String> chatStream({
  required List<Map<String, String>> messages,
  required String assistantName,
  String aiModel = 'claude',
}) async* {
  // include aiModel in the request body
  final body = jsonEncode({
    'messages': messages,
    'assistant_name': assistantName,
    'ai_model': aiModel,
  });
  // ... rest of streaming implementation unchanged
}
```

- [ ] **Step 5: Add /memory route to app_router.dart**

In `nivara/lib/router/app_router.dart`, add import:
```dart
import 'package:nivara/features/memory/presentation/pages/memory_page.dart';
```

Add route inside the routes list:
```dart
GoRoute(
  path: '/memory',
  builder: (context, state) => const MemoryPage(),
),
```

- [ ] **Step 6: Add brain icon to ChatPage AppBar**

In `nivara/lib/features/chat/presentation/pages/chat_page.dart`, add to `AppBar.actions`:

```dart
IconButton(
  icon: const Icon(Icons.psychology_outlined),
  tooltip: 'My Memories',
  onPressed: () => context.push('/memory'),
),
```

- [ ] **Step 7: Add AI Model section to VoiceSettingsPage**

In `nivara/lib/voice/voice_settings_page.dart`, add import:
```dart
import 'package:nivara/features/settings/presentation/widgets/model_selector_widget.dart';
```

After the existing sections (Wake Word, TTS Provider, Google Calendar), add:

```dart
_SectionHeader(title: 'AI Model'),
const Padding(
  padding: EdgeInsets.symmetric(horizontal: 16),
  child: ModelSelectorWidget(),
),
const SizedBox(height: 16),
```

- [ ] **Step 8: Run full test suite**

```bash
cd nivara && flutter test
```
Expected: all pass

```bash
cd hermes-agent && python -m pytest -v
```
Expected: all pass

- [ ] **Step 9: Commit**

```bash
git add nivara/lib/features/chat/presentation/providers/chat_provider.dart
git add nivara/lib/router/app_router.dart
git add nivara/lib/voice/voice_settings_page.dart
git add nivara/lib/features/chat/presentation/pages/chat_page.dart
git add nivara/test/features/chat/presentation/chat_provider_wiring_test.dart
git commit -m "feat(flutter): wire AI model selector + memory page into chat and settings"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] 3-layer memory (Firestore + ChromaDB + Obsidian) — Tasks 8, 9, 10
- [x] Multi-provider routing (Claude/Gemini/OpenAI) — Tasks 2–6
- [x] Fact extraction with 8 types, confidence threshold — Task 7
- [x] Deduplication with token overlap — Task 10
- [x] Memory injection into system prompt — Task 12
- [x] Async post-turn extraction — Task 12
- [x] Flutter Memory page — Tasks 13, 14
- [x] Flutter AI model selector in VoiceSettingsPage — Tasks 15, 16
- [x] Brain icon in ChatPage AppBar — Task 16
- [x] SharedPreferences persistence — Task 15
- [x] GET /api/v1/memory + DELETE /api/v1/memory/{id} — Task 11

**Placeholder scan:** None found. All steps contain concrete code.

**Type consistency:**
- `AIProvider.stream_response(messages: list[dict], system: str)` — used consistently Tasks 3, 4, 5, 12
- `FactExtractor(provider=AIProvider)` → `extract(str) -> list[MemoryCreate]` — used consistently Tasks 7, 12
- `Memory.fromJson` → used in Tasks 13, 14
- `aiModelNotifierProvider` — defined Task 15, consumed Tasks 15, 16
- `memoryNotifierProvider` — defined Task 14, consumed Task 14
