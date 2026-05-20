import pytest


@pytest.mark.asyncio
async def test_list_items_empty(client):
    response = await client.get("/api/items")
    assert response.status_code == 200
    body = response.json()
    assert body["data"] == []
    assert body["meta"]["count"] == 0


@pytest.mark.asyncio
async def test_create_item_valid_returns_201(client):
    payload = {"name": "Laptop Dell XPS", "description": "13.3 pulgadas, 16GB RAM"}
    response = await client.post("/api/items", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert body["data"]["name"] == payload["name"]
    assert body["data"]["description"] == payload["description"]
    assert body["data"]["id"] > 0
    assert body["data"]["created_at"]


@pytest.mark.asyncio
async def test_create_item_without_description_succeeds(client):
    response = await client.post("/api/items", json={"name": "Mouse"})
    assert response.status_code == 201
    assert response.json()["data"]["description"] is None


@pytest.mark.asyncio
async def test_create_item_empty_name_returns_422(client):
    response = await client.post("/api/items", json={"name": ""})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_item_name_too_long_returns_422(client):
    response = await client.post("/api/items", json={"name": "x" * 121})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_item_missing_name_returns_422(client):
    response = await client.post("/api/items", json={})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_list_items_after_create_returns_data(client):
    await client.post("/api/items", json={"name": "Item A"})
    await client.post("/api/items", json={"name": "Item B"})

    response = await client.get("/api/items")
    assert response.status_code == 200
    body = response.json()
    assert body["meta"]["count"] == 2
    names = [item["name"] for item in body["data"]]
    assert "Item A" in names
    assert "Item B" in names


@pytest.mark.asyncio
async def test_list_items_respects_limit(client):
    for i in range(5):
        await client.post("/api/items", json={"name": f"Item {i}"})

    response = await client.get("/api/items?limit=2")
    body = response.json()
    assert body["meta"]["count"] == 2


@pytest.mark.asyncio
async def test_list_items_respects_offset(client):
    for i in range(3):
        await client.post("/api/items", json={"name": f"Item {i}"})

    response = await client.get("/api/items?offset=1&limit=10")
    body = response.json()
    assert body["meta"]["count"] == 2


@pytest.mark.asyncio
async def test_list_items_invalid_limit_returns_422(client):
    response = await client.get("/api/items?limit=0")
    assert response.status_code == 422

    response = await client.get("/api/items?limit=101")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_get_item_by_id_found(client):
    create_resp = await client.post("/api/items", json={"name": "Findable"})
    item_id = create_resp.json()["data"]["id"]

    response = await client.get(f"/api/items/{item_id}")
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Findable"


@pytest.mark.asyncio
async def test_get_item_by_id_not_found_returns_404(client):
    response = await client.get("/api/items/99999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Item not found"


@pytest.mark.asyncio
async def test_get_item_by_id_invalid_returns_422(client):
    response = await client.get("/api/items/not-a-number")
    assert response.status_code == 422
