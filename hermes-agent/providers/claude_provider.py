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

MOOD_SYSTEM = (
    "You are a mood scoring assistant. Given the user message below, "
    "output ONLY a JSON object with two fields: "
    '"score" (integer 1-5, where 1=very negative, 3=neutral, 5=very positive) '
    'and "label" (a short lowercase word describing the mood, e.g. "anxious", "neutral", "happy"). '
    "No explanation, no markdown, just raw JSON."
)


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

    async def score_mood(self, user_text: str) -> str:
        response = await self._client.messages.create(
            model=EXTRACTION_MODEL,
            max_tokens=64,
            system=MOOD_SYSTEM,
            messages=[{"role": "user", "content": user_text}],
        )
        return response.content[0].text.strip()
