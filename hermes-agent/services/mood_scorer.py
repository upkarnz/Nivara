from __future__ import annotations

import json
import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from providers.base import AIProvider

logger = logging.getLogger(__name__)


async def score_mood(user_text: str, provider: "AIProvider") -> dict | None:
    """Score user mood. Returns {"score": int, "label": str} with score in [1, 5], or None on any error."""
    try:
        raw = await provider.score_mood(user_text)
    except Exception as e:
        logger.debug("Mood provider call failed: %s", e)
        return None
    # Strip markdown code fences that LLMs sometimes add
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]  # drop first line (```json or ```)
        raw = raw.rsplit("```", 1)[0]  # drop closing ```
        raw = raw.strip()
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError, ValueError):
        return None
    try:
        score = int(data["score"])
        label = str(data["label"])
    except (KeyError, ValueError, TypeError):
        return None
    if not (1 <= score <= 5):
        return None
    return {"score": score, "label": label}
