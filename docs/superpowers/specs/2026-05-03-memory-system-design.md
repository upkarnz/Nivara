# Memory System + Multi-Provider Routing — Design Spec

**Date:** 2026-05-03
**Plan:** 4
**Status:** Approved

---

## Goal

Give Nivara persistent, layered memory so the AI companion remembers facts about the user across conversations. Simultaneously wire up multi-provider AI routing (Claude / Gemini / OpenAI) so the user can choose their preferred model.

## Architecture

All memory logic lives in the Hermes Python backend. The Flutter app gains one new page (Memory) and a model selector widget. No changes to the SSE chat contract.

```
Flutter app
  │
  ├── ChatPage ──────────────→ POST /api/v1/chat/stream  (ai_model param added)
  │                                    │
  │                              [1] retrieve top-5 memories (ChromaDB similarity)
  │                              [2] fetch last-10 hot memories (Firestore, ordered by lastReinforced desc)
  │                              [3] inject both into system prompt
  │                              [4] route to selected AI provider
  │                              [5] stream response to Flutter
  │                              [6] async post-turn: extract facts → 3 layers
  │
  └── MemoryPage ────────────→ GET/DELETE /api/v1/memory
```

---

## Layer 1: Firestore Hot Memory

**Collection:** `users/{uid}/memories`

**Document schema:**
```json
{
  "id": "auto",
  "uid": "firebase-uid",
  "type": "routine",
  "content": "wakes up at 6am",
  "entities": ["upkar"],
  "confidence": 0.9,
  "createdAt": "2026-05-03T10:00:00Z",
  "updatedAt": "2026-05-03T10:00:00Z",
  "lastReinforced": "2026-05-03T10:00:00Z",
  "source": "conversation"
}
```

**Purpose:** Fast CRUD, Flutter Memory UI, recent-memory injection.

**Deduplication:** Before writing a new fact, query Firestore for existing facts of the same type with similar content. If a match exists (confidence > 0.8), update `lastReinforced` and `updatedAt` instead of inserting a duplicate.

---

## Layer 2: ChromaDB Vector Memory

**Deployment:** In-process within the Hermes FastAPI service. One ChromaDB collection per user, named `memories_{uid}`.

**Embedding model:** `sentence-transformers/all-MiniLM-L6-v2` (free, runs locally, ~80MB).

**Operations:**
- **Upsert:** after fact extraction, embed `content` and upsert with the Firestore document ID as the ChromaDB document ID (`memory_id`)
- **Query:** on each chat turn, embed the last user message and retrieve top-5 most similar memories

**Metadata stored alongside each vector:** `type`, `content`, `uid`, `firestore_id`

---

## Layer 3: Obsidian Graph (Local REST API)

**Plugin:** Obsidian Local REST API (`localhost:27123`). Vault synced via iCloud/Obsidian Sync.

**Trigger:** Automatic, every turn, async (fire-and-forget — never blocks the SSE stream).

**Entity extraction:** From each extracted fact, identify named entities (people, places, products, projects). For each entity, create or update a note at `Memory/{entity}.md` in the vault.

**Note format:**
```markdown
# Sarah

## Facts
- Partner of Upkar (2026-05-03)

## Connections
- [[Upkar]]
- [[Nivara]]
```

**Failure handling:** Obsidian REST calls wrapped in `asyncio.create_task` with a timeout of 3 seconds. Failure is logged and silently ignored — Obsidian being offline never affects chat.

---

## Fact Extraction

After each chat turn, a separate non-streaming AI call extracts structured facts. Uses the cheapest model for the selected provider to keep cost low.

**Model mapping for extraction:**

| Provider | Extraction model |
|----------|-----------------|
| `claude` | `claude-haiku-4-5` |
| `gemini` | `gemini-2.0-flash` |
| `openai` | `gpt-4o-mini` |

**Fact types:**

| Type | Example |
|------|---------|
| `personal_fact` | "My name is Upkar" |
| `preference` | "Prefers dark mode" |
| `routine` | "Wakes up at 6am" |
| `relationship` | "Partner is Sarah" |
| `decision` | "Decided to use Flutter" |
| `goal` | "Launch Nivara by June" |
| `emotional_signal` | "Feeling overwhelmed today" |
| `work_context` | "Building a memory system" |

**Extraction output (JSON):**
```json
[
  {
    "type": "routine",
    "content": "wakes up at 6am",
    "entities": ["upkar"],
    "confidence": 0.9
  }
]
```

Facts with `confidence < 0.6` are discarded. Empty arrays (no facts found) are a valid result and require no write operations.

---

## Multi-Provider Routing

The Hermes backend gains an `AIProvider` protocol and three concrete implementations.

**Provider protocol (`providers/base.py`):**
```python
class AIProvider(Protocol):
    async def stream_response(
        self, messages: list[ChatMessage], system: str
    ) -> AsyncGenerator[str, None]: ...

    async def extract_facts(self, prompt: str) -> str: ...
```

**Routing (`providers/router.py`):**
```python
def get_provider(ai_model: str) -> AIProvider:
    match ai_model:
        case "gemini": return GeminiProvider()
        case "openai": return OpenAIProvider()
        case _:        return ClaudeProvider()  # default
```

**Chat model per provider:**

| `ai_model` | Chat model | Extraction model |
|------------|-----------|-----------------|
| `claude` | `claude-sonnet-4-6` | `claude-haiku-4-5` |
| `gemini` | `gemini-2.0-flash` | `gemini-2.0-flash` |
| `openai` | `gpt-4o` | `gpt-4o-mini` |

**Environment variables required:**
- `ANTHROPIC_API_KEY` (existing)
- `GOOGLE_API_KEY` (new, optional — only needed if user selects Gemini)
- `OPENAI_API_KEY` (new, optional — only needed if user selects OpenAI)

Missing provider keys return a 400 error with a clear message: `"GOOGLE_API_KEY not configured on server"`.

---

## Memory Injection into System Prompt

Before calling the AI provider, retrieved memories are formatted and prepended to the system prompt:

```
You are {assistant_name}, a warm and caring AI companion.

## What you know about the user
- [routine] wakes up at 6am
- [goal] wants to launch Nivara by June
- [relationship] partner is Sarah
- [emotional_signal] feeling overwhelmed with work (2026-05-03)

Use this naturally in conversation. Do not recite this list.
Reference it when relevant (e.g. "Since you mentioned you wake at 6am...").
```

---

## Flutter Changes

### Model Selector
A `ModelSelectorWidget` (dropdown: Claude / Gemini / OpenAI) added to:
- ChatPage AppBar
- VoiceSettingsPage (existing AI settings section)

Selection persisted to SharedPreferences key `selected_ai_model`. Passed as `ai_model` in every `HermesClient.chatStream()` call.

### Memory Page (`/memory`)
Accessible via brain icon in ChatPage AppBar.

- Lists all memories from `GET /api/v1/memory` (returns all memories for the authenticated user, ordered by `lastReinforced` desc) grouped by type
- Each memory tile has a delete button (`DELETE /api/v1/memory/{id}`)
- AppBar has "Clear all" icon (`DELETE /api/v1/memory`)
- Empty state: "No memories yet. Start chatting!"

### HermesClient
`chatStream()` gains `aiModel` parameter (defaults to `"claude"`). No other changes.

---

## Backend File Structure

```
hermes-agent/
  models/
    memory.py              — Memory, FactExtractionResult pydantic models
  providers/
    __init__.py
    base.py                — AIProvider Protocol
    claude_provider.py     — Claude implementation (from claude_service.py)
    gemini_provider.py     — Gemini implementation
    openai_provider.py     — OpenAI implementation
    router.py              — get_provider(ai_model)
  services/
    memory_service.py      — orchestrates all 3 layers
    chroma_service.py      — ChromaDB upsert + query
    obsidian_service.py    — Obsidian Local REST API calls
    fact_extractor.py      — extraction prompt + JSON parse
    claude_service.py      — kept for backwards compat, delegates to claude_provider
  routers/
    chat.py                — modified: memory injection + provider routing
    memory.py              — new: GET/DELETE /api/v1/memory
  main.py                  — register memory router
  requirements.txt         — add: chromadb, sentence-transformers,
                             google-generativeai, openai
```

## Flutter File Structure

```
nivara/lib/
  features/
    memory/
      domain/memory.dart
      data/memory_repository.dart
      presentation/
        pages/memory_page.dart
        providers/memory_provider.dart
        widgets/memory_tile.dart
  shared/widgets/
    model_selector_widget.dart
  router/app_router.dart              — add /memory route
  features/chat/
    presentation/pages/chat_page.dart — brain icon + model selector
    data/hermes_client.dart           — ai_model param
  voice/voice_settings_page.dart      — model selector tile
```

---

## Error Handling

| Failure | Behaviour |
|---------|-----------|
| ChromaDB query fails | Skip memory injection, proceed with empty context |
| Firestore read fails | Skip hot memory injection, proceed |
| Fact extraction fails | Log, skip write — chat response already delivered |
| Obsidian unreachable | Log, ignore — async fire-and-forget |
| Provider key missing | Return HTTP 400 before streaming starts |
| Provider API error | Propagate as HTTP 500, same as existing behaviour |

---

## Testing

**Backend:**
- `test_fact_extractor.py` — mock Claude response, assert JSON parse
- `test_memory_service.py` — mock Firestore + ChromaDB, assert write/dedup logic
- `test_chroma_service.py` — in-memory ChromaDB client, assert upsert + query
- `test_obsidian_service.py` — mock httpx, assert note format
- `test_provider_router.py` — assert correct provider returned per ai_model string
- `test_chat_router.py` — assert system prompt contains injected memories

**Flutter:**
- `test/memory/memory_repository_test.dart` — mock HTTP, assert parse
- `test/memory/memory_page_test.dart` — widget test, assert tiles render + delete calls repo
