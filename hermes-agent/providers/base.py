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
