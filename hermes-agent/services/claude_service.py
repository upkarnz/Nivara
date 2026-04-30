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
    system_prompt = f"You are {assistant_name}, a warm and caring AI companion."
    anthropic_messages = [
        {"role": m.role.value, "content": m.content} for m in messages
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
