import logging
import os
from collections.abc import AsyncGenerator

from anthropic import (
    APIConnectionError,
    APIStatusError,
    AsyncAnthropic,
    AuthenticationError,
    RateLimitError,
)

from models.message import ChatMessage

logger = logging.getLogger(__name__)

MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6")

_client: AsyncAnthropic | None = None


def get_client() -> AsyncAnthropic:
    """Return a lazily-initialized AsyncAnthropic client."""
    global _client
    if _client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY environment variable is not set")
        _client = AsyncAnthropic(api_key=api_key)
    return _client


async def stream_claude_response(
    messages: list[ChatMessage],
    assistant_name: str = "Rocky",
) -> AsyncGenerator[str, None]:
    """Stream a Claude response as text chunks."""
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
    # Strip system-role messages from the list — Claude API takes them via the
    # system param; passing them as messages causes an API error.
    anthropic_messages = [
        {"role": m.role.value, "content": m.content}
        for m in messages
        if m.role.value != "system"
    ]

    try:
        async with get_client().messages.stream(
            model=MODEL,
            max_tokens=1024,
            system=system_prompt,
            messages=anthropic_messages,
        ) as stream:
            async for text in stream.text_stream:
                yield text
    except RateLimitError:
        logger.warning("Anthropic rate limit hit for user request")
        raise
    except AuthenticationError:
        logger.error("Anthropic authentication failed - check ANTHROPIC_API_KEY")
        raise
    except (APIConnectionError, APIStatusError) as e:
        logger.exception("Anthropic API error: %s", e)
        raise
