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

_MOOD_SYSTEM = (
    "You are a mood scoring assistant. Given the user message, "
    "output ONLY a JSON object with two fields: "
    '"score" (integer 1-5) and "label" (short lowercase word). No markdown.'
)


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

    async def score_mood(self, user_text: str) -> str:
        response = await self._client.chat.completions.create(
            model=EXTRACTION_MODEL,
            max_tokens=64,
            messages=[
                {"role": "system", "content": _MOOD_SYSTEM},
                {"role": "user", "content": user_text},
            ],
        )
        content = response.choices[0].message.content or ""
        return content.strip()
