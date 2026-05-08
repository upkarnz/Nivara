# hermes-agent/services/claude_service.py
"""Backwards-compatible wrapper around ClaudeProvider."""
import os
from typing import AsyncGenerator
from anthropic import AsyncAnthropic
from providers.claude_provider import ClaudeProvider
from models.message import ChatMessage

# Global provider instance - can be replaced in tests
_provider = ClaudeProvider()
_client: AsyncAnthropic | None = None


def get_client() -> AsyncAnthropic:
    """Return a lazily-initialized AsyncAnthropic client.

    Kept for backwards compatibility with existing code.
    """
    global _client
    if _client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY environment variable is not set")
        _client = AsyncAnthropic(api_key=api_key)
    return _client


def get_provider() -> ClaudeProvider:
    """Return the global ClaudeProvider instance."""
    return _provider


async def stream_claude_response(
    messages: list[dict] | list[ChatMessage],
    assistant_name: str = "Nivara",
) -> AsyncGenerator[str, None]:
    """Stream a Claude response as text chunks.

    Args:
        messages: List of message dicts or ChatMessage objects.
        assistant_name: Name of the AI assistant.

    Yields:
        Text chunks from the Claude API.
    """
    system = f"You are {assistant_name}, a helpful personal AI assistant."

    # Convert ChatMessage objects to dicts for backwards compatibility
    anthropic_messages = []
    for msg in messages:
        if isinstance(msg, ChatMessage):
            anthropic_messages.append({"role": msg.role.value, "content": msg.content})
        else:
            anthropic_messages.append(msg)

    provider = get_provider()
    async for chunk in provider.stream_response(anthropic_messages, system):
        yield chunk
