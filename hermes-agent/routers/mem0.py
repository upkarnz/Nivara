"""mem0 proxy router — Firebase-authed endpoints that call mem0 server-side."""
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from auth.firebase_jwt import get_current_user
from models.user import TokenData
from services import mem0_service

router = APIRouter()


class InsertBody(BaseModel):
    messages: list[dict]


@router.post("/insert")
async def insert_memory(
    body: InsertBody,
    current_user: TokenData = Depends(get_current_user),
):
    await mem0_service.insert_turn(current_user.uid, body.messages)
    return {"status": "ok"}


@router.get("/context")
async def get_context(
    query: str = Query(default=""),
    current_user: TokenData = Depends(get_current_user),
):
    ctx = await mem0_service.get_context(current_user.uid, query=query or None)
    return {"context": ctx}
