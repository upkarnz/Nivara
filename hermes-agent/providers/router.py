from providers.base import AIProvider


def get_provider(ai_model: str) -> AIProvider:
    raise NotImplementedError("Router not yet wired")
