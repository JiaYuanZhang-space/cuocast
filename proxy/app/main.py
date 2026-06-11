from fastapi import FastAPI, HTTPException
import httpx
from app.config import settings, TTL
from app.cache import TTLCache
from app.upstream import ApiFootball
from app.service import cached_fetch
from app import mappers
from app.odds_scraper import fetch_odds

app = FastAPI(title="WorldCup Proxy")
cache = TTLCache()
api = ApiFootball(key=settings.api_football_key, base=settings.api_football_base)

LEAGUE = {"league": settings.wc_league_id, "season": settings.wc_season}

@app.get("/health")
def health():
    return {"status": "ok"}

async def _fixtures(extra: dict, key: str, ttl: int, mapper):
    async def fetch():
        raw = await api.get("/fixtures", params={**LEAGUE, **extra})
        return mapper(raw)
    try:
        return await cached_fetch(cache, key, ttl, fetch)
    except httpx.HTTPStatusError:
        raise HTTPException(status_code=502, detail="upstream unavailable")

@app.get("/fixtures")
async def fixtures():
    return await _fixtures({}, "fixtures", TTL["fixtures"], mappers.map_fixtures)

@app.get("/live")
async def live():
    return await _fixtures({"live": "all"}, "live", TTL["live"], mappers.map_fixtures)

@app.get("/results")
async def results():
    return await _fixtures({"status": "FT"}, "results", TTL["results"], mappers.map_fixtures)

@app.get("/standings")
async def standings():
    async def fetch():
        raw = await api.get("/standings", params=LEAGUE)
        return mappers.map_standings(raw)
    try:
        return await cached_fetch(cache, "standings", TTL["standings"], fetch)
    except httpx.HTTPStatusError:
        raise HTTPException(status_code=502, detail="upstream unavailable")

@app.get("/odds")
async def odds(matchId: str):
    import app.main as _self
    async def fetch():
        return await _self.fetch_odds(matchId)
    try:
        return await cached_fetch(cache, f"odds:{matchId}", TTL["odds"], fetch)
    except Exception:
        return {"data": None, "stale": True}
