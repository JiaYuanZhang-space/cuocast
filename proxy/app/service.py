from typing import Awaitable, Callable
from app.cache import TTLCache

async def cached_fetch(cache: TTLCache, key: str, ttl: float,
                       fetch: Callable[[], Awaitable]) -> dict:
    hit = cache.get(key)
    if hit is not None:
        return {"data": hit, "stale": False}
    try:
        data = await fetch()
    except Exception:
        stale = cache.get_stale(key)
        if stale is not None:
            return {"data": stale, "stale": True}
        raise
    cache.set(key, data, ttl=ttl)
    return {"data": data, "stale": False}
