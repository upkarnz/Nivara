import routers.memory as _self
from fastapi import APIRouter, Depends, status
from auth.firebase_jwt import get_current_user
from models.user import TokenData
from models.memory import Memory

router = APIRouter()

# Lazily initialised on first request so Firebase is already up.
memory_service = None


def _ensure_service():
    if _self.memory_service is None:
        from services.memory_service import MemoryService

        _self.memory_service = MemoryService()
    return _self.memory_service


@router.get("", response_model=list[Memory])
async def list_memories(
    current_user: TokenData = Depends(get_current_user),
) -> list[Memory]:
    return await _ensure_service().list_memories(current_user.uid)


@router.delete("/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_memory(
    memory_id: str,
    current_user: TokenData = Depends(get_current_user),
) -> None:
    await _ensure_service().delete_memory(current_user.uid, memory_id)
