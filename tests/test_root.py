import pytest


@pytest.mark.asyncio
async def test_root_returns_service_info(client):
    response = await client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "eval-final-dgiti"
    assert body["docs"] == "/docs"
    assert body["health"] == "/health"


@pytest.mark.asyncio
async def test_request_id_header_propagated(client):
    response = await client.get("/", headers={"X-Request-ID": "test-123"})
    assert response.headers.get("X-Request-ID") == "test-123"


@pytest.mark.asyncio
async def test_request_id_generated_when_missing(client):
    response = await client.get("/")
    assert "X-Request-ID" in response.headers
    assert len(response.headers["X-Request-ID"]) > 0


@pytest.mark.asyncio
async def test_openapi_schema_available(client):
    response = await client.get("/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    assert schema["info"]["title"] == "eval-final-dgiti"
    assert "/health" in schema["paths"]
    assert "/api/items" in schema["paths"]
