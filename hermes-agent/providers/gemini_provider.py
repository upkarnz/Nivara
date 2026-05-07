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
