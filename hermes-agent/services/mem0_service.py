"""Mem0 memory service — proxies calls to api.mem0.ai using server-side API key."""
import logging
import os
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

MEM0_API_BASE = "https://api.mem0.ai"
_API_KEY = os.environ.get("MEM0_API_KEY", "")


def _headers() -> dict:
    return {
        "Authorization": f"Token {_API_KEY}",
        "Content-Type": "application/json",
    }


async def insert_turn(uid: str, messages: list[dict]) -> None:
    """Send a conversation turn to Mem0 so it can update the user's profile."""
    if not _API_KEY:
        logger.debug("MEM0_API_KEY not set — skipping insert")
        return

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            f"{MEM0_API_BASE}/v1/memories/",
            headers=_headers(),
            json={"messages": messages, "user_id": uid},
        )
        if resp.status_code not in (200, 201):
            logger.warning("mem0 insert failed: %s %s", resp.status_code, resp.text[:200])


async def get_context(uid: str, query: Optional[str] = None, limit: int = 10) -> Optional[str]:
    """Return a formatted memory context string for injection into the AI prompt.

    Uses semantic search when a query is provided, otherwise fetches recent memories.
    Returns None when the user has no profile yet or the key is unset.
    """
    if not _API_KEY:
        return None

    async with httpx.AsyncClient(timeout=10.0) as client:
        if query:
            resp = await client.post(
                f"{MEM0_API_BASE}/v1/memories/search/",
                headers=_headers(),
                json={"query": query, "user_id": uid, "limit": limit},
            )
        else:
            resp = await client.get(
                f"{MEM0_API_BASE}/v1/memories/",
                headers=_headers(),
                params={"user_id": uid, "limit": str(limit)},
            )

    if resp.status_code != 200:
        logger.warning("mem0 context fetch failed: %s", resp.status_code)
        return None

    data = resp.json()
    memories = data if isinstance(data, list) else data.get("results", [])

    if not memories:
        return None

    lines = [
        f"- {m['memory']}"
        for m in memories
        if isinstance(m, dict) and m.get("memory")
    ]

    if not lines:
        return None

    return (
        "# Memory\n"
        "Unless the user has a relevant query, do not actively mention "
        "these memories in the conversation.\n"
        "## User Background:\n" + "\n".join(lines)
    )
