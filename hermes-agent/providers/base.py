from abc import ABC, abstractmethod
from typing import AsyncGenerator


class AIProvider(ABC):
    @abstractmethod
    async def stream_response(
        self,
        messages: list[dict],
        system: str,
    ) -> AsyncGenerator[str, None]:
        """Stream tokens for a chat turn."""
        ...

    @abstractmethod
    async def extract_facts(self, prompt: str) -> str:
        """Extract facts from conversation text, return raw JSON string."""
        ...

    @abstractmethod
    async def score_mood(self, user_text: str) -> str:
        """Score user mood from text. Returns JSON string: {"score": int 1-5, "label": str}.
        Raise on any error — caller handles exceptions."""
        ...
