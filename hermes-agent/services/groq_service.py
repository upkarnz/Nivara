import logging
import os
from collections.abc import AsyncGenerator

import httpx

from models.message import ChatMessage

logger = logging.getLogger(__name__)

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
MODEL = os.environ.get("GROQ_MODEL", "llama3-8b-8192")


async def stream_groq_response(
    messages: list[ChatMessage],
    assistant_name: str = "Rocky",
) -> AsyncGenerator[str, None]:
    """Stream a Groq response as text chunks via the OpenAI-compatible SSE API."""
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY environment variable is not set")

    system_prompt = (
        f"You are {assistant_name}, a warm and caring AI companion.\n\n"
        "## Scheduling events\n"
        "When the user asks to schedule, book, create, or add an event, meeting, "
        "appointment, or reminder, confirm briefly and append a JSON block at the "
        "very end of your response in this exact format (no extra keys):\n\n"
        "```json\n"
        '{{"schedule_event": {{"title": "Event title", "start": "YYYY-MM-DDTHH:MM:SS", "end": "YYYY-MM-DDTHH:MM:SS"}}}}\n'
        "```\n\n"
        "Rules:\n"
        "- Use ISO 8601 local time (no timezone suffix).\n"
        "- If no end time is given, default to 1 hour after start.\n"
        "- If the user gives a date without a year, use the current year.\n"
        "- Only emit this block when actually creating an event, not for general date questions."
    )

    groq_messages = [{"role": "system", "content": system_prompt}]
    groq_messages += [
        {"role": m.role.value, "content": m.content}
        for m in messages
        if m.role.value != "system"
    ]

    payload = {
        "model": MODEL,
        "messages": groq_messages,
        "stream": True,
        "max_tokens": 1024,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        async with client.stream("POST", GROQ_API_URL, json=payload, headers=headers) as response:
            if response.status_code != 200:
                body = await response.aread()
                raise RuntimeError(f"Groq API error {response.status_code}: {body.decode()}")

            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    return
                try:
                    import json
                    chunk = json.loads(data)
                    delta = chunk["choices"][0]["delta"].get("content", "")
                    if delta:
                        yield delta
                except (KeyError, json.JSONDecodeError):
                    continue
