from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120, examples=["Laptop Dell XPS"])
    description: str | None = Field(default=None, max_length=500, examples=["13.3 pulgadas, 16GB RAM"])


class ItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None
    created_at: datetime


class Meta(BaseModel):
    request_id: str | None = None
    count: int | None = None


class ItemListResponse(BaseModel):
    data: list[ItemRead]
    meta: Meta


class ItemResponse(BaseModel):
    data: ItemRead
    meta: Meta


class HealthDetail(BaseModel):
    status: str
    db: str
    app_version: str
    environment: str


class HealthResponse(BaseModel):
    data: HealthDetail
    meta: Meta


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: list[dict] | None = None


class ErrorResponse(BaseModel):
    error: ErrorDetail
    meta: Meta
