import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Item
from app.schemas import (
    ItemCreate,
    ItemListResponse,
    ItemRead,
    ItemResponse,
    Meta,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/items", tags=["items"])


@router.get("", response_model=ItemListResponse, summary="Listar items")
async def list_items(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
) -> ItemListResponse:
    result = await db.execute(select(Item).order_by(Item.id.desc()).limit(limit).offset(offset))
    items = result.scalars().all()
    return ItemListResponse(
        data=[ItemRead.model_validate(it) for it in items],
        meta=Meta(
            request_id=getattr(request.state, "request_id", None),
            count=len(items),
        ),
    )


@router.post(
    "",
    response_model=ItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear item",
)
async def create_item(
    payload: ItemCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> ItemResponse:
    item = Item(name=payload.name, description=payload.description)
    db.add(item)
    try:
        await db.commit()
        await db.refresh(item)
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to create item")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not create item: {type(exc).__name__}",
        ) from exc

    return ItemResponse(
        data=ItemRead.model_validate(item),
        meta=Meta(request_id=getattr(request.state, "request_id", None)),
    )


@router.get("/{item_id}", response_model=ItemResponse, summary="Obtener item por id")
async def get_item(
    item_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> ItemResponse:
    item = await db.get(Item, item_id)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return ItemResponse(
        data=ItemRead.model_validate(item),
        meta=Meta(request_id=getattr(request.state, "request_id", None)),
    )
