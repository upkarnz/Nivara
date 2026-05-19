import logging

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from models.message import ChatRequest
from models.user import TokenData
from auth.firebase_jwt import get_current_user
from services.claude_service import stream_claude_response

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/chat/stream")
async def chat_stream(
    request: ChatRequest,
    current_user: TokenData = Depends(get_current_user),
):
    async def generate():
        try:
            async for chunk in stream_claude_response(
                messages=request.messages,
                assistant_name=request.assistant_name,
            ):
                yield f"data: {chunk}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            logger.error("Stream error: %s", e)
            yield "data: [ERROR]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
