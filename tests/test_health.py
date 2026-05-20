import pytest


@pytest.mark.asyncio
async def test_health_returns_200_and_ok(client):
    response = await client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["data"]["status"] == "ok"
    assert body["data"]["db"] == "connected"
    assert body["data"]["environment"] == "test"
    assert body["data"]["app_version"]
    assert "meta" in body


@pytest.mark.asyncio
async def test_health_includes_request_id_in_meta(client):
    response = await client.get("/health", headers={"X-Request-ID": "abc-xyz"})
    body = response.json()
    assert body["meta"]["request_id"] == "abc-xyz"
