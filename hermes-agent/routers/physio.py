import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from auth.firebase_jwt import get_current_user
from models.user import TokenData
from services.physio_service import analyse_physio

logger = logging.getLogger(__name__)
router = APIRouter()


class PhysioSnapshotRequest(BaseModel):
    capturedAt: str
    stepCount: int | None = None
    heartRateBpm: float | None = None
    restingHeartRateBpm: float | None = None
    hrv: float | None = None
    activeCalories: float | None = None
    sleepDurationMinutes: int | None = None
    sleepQualityLabel: str | None = None


@router.post("/analyse")
async def analyse(
    request: PhysioSnapshotRequest,
    current_user: TokenData = Depends(get_current_user),
):
    """
    Receive a PhysioSnapshot from the mobile app and return an AI-generated
    PhysioInsight (summary, contextHint, flags, generatedAt).
    """
    insight = await analyse_physio(request.model_dump())
    return insight
