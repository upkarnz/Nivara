from providers.base import AIProvider
from providers.claude_provider import ClaudeProvider


def get_provider(ai_model: str) -> AIProvider:
    match ai_model:
        case "gemini":
            from providers.gemini_provider import GeminiProvider
            return GeminiProvider()
        case "openai":
            from providers.openai_provider import OpenAIProvider
            return OpenAIProvider()
        case _:
            return ClaudeProvider()
