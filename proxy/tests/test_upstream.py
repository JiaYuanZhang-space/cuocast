import httpx, pytest, respx
from app.upstream import ApiFootball

@pytest.mark.asyncio
@respx.mock
async def test_get_fixtures_sends_key_and_returns_response():
    route = respx.get("https://v3.football.api-sports.io/fixtures").mock(
        return_value=httpx.Response(200, json={"response": [{"id": 1}]})
    )
    client = ApiFootball(key="abc", base="https://v3.football.api-sports.io")
    data = await client.get("/fixtures", params={"league": 1, "season": 2026})
    assert data == {"response": [{"id": 1}]}
    assert route.calls.last.request.headers["x-apisports-key"] == "abc"

@pytest.mark.asyncio
@respx.mock
async def test_get_raises_on_429():
    respx.get("https://v3.football.api-sports.io/fixtures").mock(
        return_value=httpx.Response(429, json={})
    )
    client = ApiFootball(key="abc", base="https://v3.football.api-sports.io")
    with pytest.raises(httpx.HTTPStatusError):
        await client.get("/fixtures", params={})
