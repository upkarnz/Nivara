import asyncio
import contextlib
import json
import logging
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from auth.firebase_jwt import get_current_user
from models.message import ChatRequest
from models.user import TokenData
from providers.router import get_provider
from services.memory_service import MemoryService
from services.fact_extractor import FactExtractor
from services.mood_scorer import score_mood

logger = logging.getLogger(__name__)
router = APIRouter()

# Module-level singleton — tests patch this name directly via `routers.chat.memory_service`.
# Initialised lazily on first real request to avoid Firebase calls at import time.
memory_service: MemoryService | None = None

_BACKGROUND_TASKS: set = set()

MEMORY_INJECT_HEADER = "\n\n## What you know about the user\nUse this naturally in conversation, don't announce it:\n"


def _build_system_prompt(assistant_name: str, memories: list) -> str:
    base = f"You are {assistant_name}, a helpful personal AI assistant."
    if not memories:
        return base
    facts = "\n".join(f"- {m.content}" for m in memories)
    return base + MEMORY_INJECT_HEADER + facts


def _resolve_memory_service() -> MemoryService:
    """Return the module-level memory_service, initialising it if not yet set."""
    global memory_service
    if memory_service is None:
        memory_service = MemoryService()
    return memory_service


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

    # Always read via _resolve so tests that patch `memory_service` to a non-None mock
    # are respected — the global reference is checked each call.
    svc = memory_service if memory_service is not None else _resolve_memory_service()
    memories = await svc.retrieve_memories(uid, last_user_text)
    system_prompt = _build_system_prompt(request.assistant_name, memories)

    provider = get_provider(request.ai_model)

    async def generate():
        full_response_parts: list[str] = []
        mood_task = asyncio.create_task(score_mood(last_user_text, provider))
        try:
            async for chunk in provider.stream_response(messages, system_prompt):
                full_response_parts.append(chunk)
                yield f"data: {chunk}\n\n"
        except Exception as e:
            logger.error("Stream error: %s", e)
            if not mood_task.done():
                mood_task.cancel()
                with contextlib.suppress(asyncio.CancelledError, Exception):
                    await mood_task
            yield "data: [ERROR]\n\n"
        else:
            try:
                mood = await asyncio.wait_for(mood_task, timeout=5.0)
                if mood is not None:
                    yield f"data: __MOOD__{json.dumps(mood)}\n\n"
            except (asyncio.TimeoutError, asyncio.CancelledError) as e:
                logger.debug("Mood event skipped: %s", e)
            except Exception as e:
                logger.debug("Mood event skipped: %s", e)
        finally:
            if not mood_task.done():
                mood_task.cancel()
                with contextlib.suppress(asyncio.CancelledError, Exception):
                    await mood_task
            full_response = "".join(full_response_parts)
            conversation_text = f"User: {last_user_text}\nAssistant: {full_response}"
            extractor = FactExtractor(provider=provider)
            task = asyncio.create_task(_extract_and_save(uid, conversation_text, svc, extractor))
            _BACKGROUND_TASKS.add(task)
            task.add_done_callback(_BACKGROUND_TASKS.discard)

    return StreamingResponse(generate(), media_type="text/event-stream")


async def _extract_and_save(
    uid: str, conversation_text: str, svc: MemoryService, extractor: FactExtractor
) -> None:
    try:
        facts = await extractor.extract(conversation_text)
        for fact in facts:
            await svc.save_memory(uid, fact)
    except Exception as e:
        logger.warning("Post-turn extraction failed: %s", e)
