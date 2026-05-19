import logging

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from models.message import ChatRequest
from models.user import TokenData
from auth.firebase_jwt import get_current_user
from services.claude_service import stream_claude_response
from services.groq_service import stream_groq_response

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/chat/stream")
async def chat_stream(
    request: ChatRequest,
    current_user: TokenData = Depends(get_current_user),
):
    use_groq = request.ai_model.lower() in ("groq", "llama", "llama3")

    async def generate():
        try:
            stream_fn = stream_groq_response if use_groq else stream_claude_response
            async for chunk in stream_fn(
                messages=request.messages,
                assistant_name=request.assistant_name,
            ):
                yield f"data: {chunk}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            logger.error("Stream error (%s): %s", request.ai_model, e)
            yield "data: [ERROR]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
