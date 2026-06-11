import httpx, pytest
from app.cache import TTLCache
from app.service import cached_fetch

@pytest.mark.asyncio
async def test_returns_fresh_and_caches():
    cache = TTLCache()
    calls = []
    async def fetch():
        calls.append(1)
        return [{"id": 1}]
    out = await cached_fetch(cache, "k", ttl=10, fetch=fetch)
    assert out == {"data": [{"id": 1}], "stale": False}
    out2 = await cached_fetch(cache, "k", ttl=10, fetch=fetch)
    assert out2["stale"] is False
    assert len(calls) == 1

@pytest.mark.asyncio
async def test_falls_back_to_stale_on_error():
    cache = TTLCache(now=lambda: 100.0)
    cache.set("k", [{"id": 9}], ttl=5)
    cache._now = lambda: 200.0
    async def fetch():
        raise httpx.HTTPStatusError("429", request=None, response=None)
    out = await cached_fetch(cache, "k", ttl=10, fetch=fetch)
    assert out == {"data": [{"id": 9}], "stale": True}

@pytest.mark.asyncio
async def test_error_with_no_cache_raises():
    cache = TTLCache()
    async def fetch():
        raise httpx.HTTPStatusError("429", request=None, response=None)
    with pytest.raises(httpx.HTTPStatusError):
        await cached_fetch(cache, "k", ttl=10, fetch=fetch)
