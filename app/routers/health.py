import logging

from fastapi import APIRouter, Depends, Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.schemas import HealthDetail, HealthResponse, Meta

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, summary="Health check")
async def health_check(request: Request, db: AsyncSession = Depends(get_db)) -> HealthResponse:
    db_status = "connected"
    try:
        result = await db.execute(text("SELECT 1"))
        result.scalar_one()
    except Exception as exc:
        logger.exception("Health check DB failure")
        db_status = f"error: {type(exc).__name__}"

    return HealthResponse(
        data=HealthDetail(
            status="ok" if db_status == "connected" else "degraded",
            db=db_status,
            app_version=settings.app_version,
            environment=settings.environment,
        ),
        meta=Meta(request_id=getattr(request.state, "request_id", None)),
    )
