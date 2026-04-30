import os
from collections.abc import AsyncGenerator

from anthropic import AsyncAnthropic

from models.message import ChatMessage

client = AsyncAnthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))


async def stream_claude_response(
    messages: list[ChatMessage],
    assistant_name: str = "Rocky",
) -> AsyncGenerator[str, None]:
    """Stream a Claude response as text chunks."""
    system_prompt = f"You are {assistant_name}, a warm and caring AI companion."
    anthropic_messages = [
        {"role": m.role.value, "content": m.content} for m in messages
    ]

    async with client.messages.stream(
        model="claude-opus-4-5",
        max_tokens=1024,
        system=system_prompt,
        messages=anthropic_messages,
    ) as stream:
        async for text in stream.text_stream:
            yield text
