# 后端代理 (FastAPI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 FastAPI 代理服务, 持密钥、缓存、限流降级, 把 API-Football 与第三方竞彩赔率统一成 App 友好的精简 JSON。

**Architecture:** 单进程 FastAPI。请求经端点 → 查 TTL 内存缓存 → 未命中则调上游(API-Football)或读赔率缓存 → 经 mapper 转精简 JSON 返回。上游错误时返回上次缓存并标 `stale:true`。赔率由后台抓取器从保存的 HTML 解析。

**Tech Stack:** Python 3.11, FastAPI, uvicorn, httpx, pytest, pytest-asyncio, respx(mock httpx), selectolax(HTML 解析)。

---

## 文件结构

```
proxy/
  app/
    __init__.py
    config.py          # 环境配置 + TTL 常量
    cache.py           # TTL 内存缓存
    upstream.py        # API-Football httpx 客户端
    mappers.py         # 上游 JSON → App JSON
    odds_scraper.py    # 第三方赔率 HTML 解析
    service.py         # 缓存 + 上游/降级编排
    main.py            # FastAPI app + 路由
  tests/
    __init__.py
    fixtures/          # 录制的上游响应 + 赔率 HTML 样本
    test_cache.py
    test_upstream.py
    test_mappers.py
    test_odds_scraper.py
    test_service.py
    test_endpoints.py
  requirements.txt
  .env.example
  README.md
```

设计边界: `cache` 只管存取过期; `upstream` 只管调 API-Football; `mappers` 纯函数转换; `odds_scraper` 纯解析; `service` 编排(缓存+降级); `main` 只接路由。各文件单一职责, 可独立测试。

---

## Task 0: 项目脚手架

**Files:**
- Create: `proxy/requirements.txt`
- Create: `proxy/.env.example`
- Create: `proxy/app/__init__.py`
- Create: `proxy/tests/__init__.py`
- Create: `proxy/app/main.py`
- Test: `proxy/tests/test_endpoints.py`

- [ ] **Step 1: 写依赖清单**

`proxy/requirements.txt`:
```
fastapi==0.115.0
uvicorn[standard]==0.30.6
httpx==0.27.2
selectolax==0.3.21
pydantic-settings==2.5.2
pytest==8.3.3
pytest-asyncio==0.24.0
respx==0.21.1
```

- [ ] **Step 2: 写 .env 样例**

`proxy/.env.example`:
```
API_FOOTBALL_KEY=your_api_sports_key_here
API_FOOTBALL_BASE=https://v3.football.api-sports.io
WC_LEAGUE_ID=1
WC_SEASON=2026
```

- [ ] **Step 3: 建空包文件**

`proxy/app/__init__.py` 和 `proxy/tests/__init__.py` 均为空文件。

- [ ] **Step 4: 写健康检查的失败测试**

`proxy/tests/test_endpoints.py`:
```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_returns_ok():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
```

- [ ] **Step 5: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.main'`

- [ ] **Step 6: 写最小 main.py**

`proxy/app/main.py`:
```python
from fastapi import FastAPI

app = FastAPI(title="WorldCup Proxy")

@app.get("/health")
def health():
    return {"status": "ok"}
```

- [ ] **Step 7: 运行确认通过**

Run: `cd proxy && pip install -r requirements.txt && python -m pytest tests/test_endpoints.py -v`
Expected: PASS

- [ ] **Step 8: 提交**

```bash
git add proxy/
git commit -m "chore(proxy): scaffold FastAPI app with health endpoint"
```

---

## Task 1: TTL 内存缓存

**Files:**
- Create: `proxy/app/cache.py`
- Test: `proxy/tests/test_cache.py`

- [ ] **Step 1: 写失败测试**

`proxy/tests/test_cache.py`:
```python
import time
from app.cache import TTLCache

def test_get_missing_returns_none():
    c = TTLCache()
    assert c.get("k") is None

def test_set_then_get_returns_value():
    c = TTLCache()
    c.set("k", {"v": 1}, ttl=10)
    assert c.get("k") == {"v": 1}

def test_expired_entry_returns_none():
    c = TTLCache(now=lambda: 100.0)
    c.set("k", "v", ttl=5)
    c._now = lambda: 106.0
    assert c.get("k") is None

def test_get_stale_returns_value_after_expiry():
    c = TTLCache(now=lambda: 100.0)
    c.set("k", "v", ttl=5)
    c._now = lambda: 106.0
    assert c.get_stale("k") == "v"
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_cache.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.cache'`

- [ ] **Step 3: 实现 cache.py**

`proxy/app/cache.py`:
```python
import time
from typing import Any, Callable, Optional

class TTLCache:
    def __init__(self, now: Callable[[], float] = time.monotonic):
        self._now = now
        self._store: dict[str, tuple[float, Any]] = {}

    def set(self, key: str, value: Any, ttl: float) -> None:
        self._store[key] = (self._now() + ttl, value)

    def get(self, key: str) -> Optional[Any]:
        entry = self._store.get(key)
        if entry is None:
            return None
        expires, value = entry
        if self._now() >= expires:
            return None
        return value

    def get_stale(self, key: str) -> Optional[Any]:
        entry = self._store.get(key)
        return entry[1] if entry else None
```

- [ ] **Step 4: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_cache.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: 提交**

```bash
git add proxy/app/cache.py proxy/tests/test_cache.py
git commit -m "feat(proxy): TTL in-memory cache with stale fallback"
```

---

## Task 2: 配置

**Files:**
- Create: `proxy/app/config.py`
- Test: `proxy/tests/test_endpoints.py`(追加)

- [ ] **Step 1: 写失败测试**

追加到 `proxy/tests/test_endpoints.py`:
```python
from app.config import Settings, TTL

def test_settings_reads_env(monkeypatch):
    monkeypatch.setenv("API_FOOTBALL_KEY", "abc")
    s = Settings()
    assert s.api_football_key == "abc"
    assert s.wc_league_id == 1

def test_ttl_constants():
    assert TTL["live"] == 30
    assert TTL["fixtures"] == 3600
    assert TTL["odds"] == 300
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -k settings -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.config'`

- [ ] **Step 3: 实现 config.py**

`proxy/app/config.py`:
```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    api_football_key: str = ""
    api_football_base: str = "https://v3.football.api-sports.io"
    wc_league_id: int = 1
    wc_season: int = 2026

TTL = {
    "live": 30,
    "fixtures": 3600,
    "results": 21600,
    "standings": 3600,
    "bracket": 3600,
    "odds": 300,
}

settings = Settings()
```

- [ ] **Step 4: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -k "settings or ttl" -v`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add proxy/app/config.py proxy/tests/test_endpoints.py
git commit -m "feat(proxy): settings and TTL constants"
```

---

## Task 3: 上游 API-Football 客户端

**Files:**
- Create: `proxy/app/upstream.py`
- Test: `proxy/tests/test_upstream.py`

- [ ] **Step 1: 写失败测试(用 respx mock httpx)**

`proxy/tests/test_upstream.py`:
```python
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
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_upstream.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.upstream'`

- [ ] **Step 3: 实现 upstream.py**

`proxy/app/upstream.py`:
```python
import httpx

class ApiFootball:
    def __init__(self, key: str, base: str, timeout: float = 8.0):
        self._headers = {"x-apisports-key": key}
        self._base = base
        self._timeout = timeout

    async def get(self, path: str, params: dict) -> dict:
        async with httpx.AsyncClient(timeout=self._timeout) as c:
            r = await c.get(self._base + path, params=params, headers=self._headers)
            r.raise_for_status()
            return r.json()
```

- [ ] **Step 4: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_upstream.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: 提交**

```bash
git add proxy/app/upstream.py proxy/tests/test_upstream.py
git commit -m "feat(proxy): API-Football async client"
```

---

## Task 4: Mappers — fixtures / live / results

**Files:**
- Create: `proxy/app/mappers.py`
- Create: `proxy/tests/fixtures/af_fixtures.json`
- Test: `proxy/tests/test_mappers.py`

- [ ] **Step 1: 存一份上游样本响应**

`proxy/tests/fixtures/af_fixtures.json`(精简但结构真实):
```json
{
  "response": [
    {
      "fixture": {"id": 101, "date": "2026-06-14T04:00:00+00:00",
                  "status": {"short": "1H", "elapsed": 23},
                  "venue": {"name": "AT&T Stadium"}},
      "league": {"round": "Group Stage - 1"},
      "teams": {"home": {"name": "Brazil"}, "away": {"name": "Germany"}},
      "goals": {"home": 1, "away": 0}
    }
  ]
}
```

- [ ] **Step 2: 写失败测试**

`proxy/tests/test_mappers.py`:
```python
import json, pathlib
from app.mappers import map_fixtures

SAMPLE = json.loads((pathlib.Path(__file__).parent / "fixtures" / "af_fixtures.json").read_text())

def test_map_fixtures_extracts_core_fields():
    out = map_fixtures(SAMPLE)
    assert out == [{
        "id": 101,
        "kickoff": "2026-06-14T04:00:00+00:00",
        "status": "1H",
        "minute": 23,
        "venue": "AT&T Stadium",
        "round": "Group Stage - 1",
        "home": "Brazil",
        "away": "Germany",
        "homeScore": 1,
        "awayScore": 0,
    }]

def test_map_fixtures_empty_response():
    assert map_fixtures({"response": []}) == []
```

- [ ] **Step 3: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_mappers.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.mappers'`

- [ ] **Step 4: 实现 mappers.py**

`proxy/app/mappers.py`:
```python
def map_fixtures(data: dict) -> list[dict]:
    out = []
    for item in data.get("response", []):
        fx = item["fixture"]
        out.append({
            "id": fx["id"],
            "kickoff": fx["date"],
            "status": fx["status"]["short"],
            "minute": fx["status"].get("elapsed"),
            "venue": fx.get("venue", {}).get("name"),
            "round": item.get("league", {}).get("round"),
            "home": item["teams"]["home"]["name"],
            "away": item["teams"]["away"]["name"],
            "homeScore": item["goals"]["home"],
            "awayScore": item["goals"]["away"],
        })
    return out
```

- [ ] **Step 5: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_mappers.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: 提交**

```bash
git add proxy/app/mappers.py proxy/tests/test_mappers.py proxy/tests/fixtures/af_fixtures.json
git commit -m "feat(proxy): fixture mapper to slim app JSON"
```

---

## Task 5: Mappers — events / standings

**Files:**
- Modify: `proxy/app/mappers.py`
- Create: `proxy/tests/fixtures/af_events.json`, `proxy/tests/fixtures/af_standings.json`
- Test: `proxy/tests/test_mappers.py`(追加)

- [ ] **Step 1: 存样本**

`proxy/tests/fixtures/af_events.json`:
```json
{"response": [
  {"time": {"elapsed": 12}, "team": {"name": "Brazil"},
   "player": {"name": "Vinicius"}, "type": "Goal", "detail": "Normal Goal"},
  {"time": {"elapsed": 34}, "team": {"name": "Germany"},
   "player": {"name": "Kimmich"}, "type": "Card", "detail": "Yellow Card"}
]}
```

`proxy/tests/fixtures/af_standings.json`:
```json
{"response": [{"league": {"standings": [[
  {"rank": 1, "team": {"name": "Mexico"}, "points": 6,
   "all": {"played": 2, "win": 2, "draw": 0, "lose": 0}, "goalsDiff": 3},
  {"rank": 2, "team": {"name": "Netherlands"}, "points": 4,
   "all": {"played": 2, "win": 1, "draw": 1, "lose": 0}, "goalsDiff": 2}
]]}}]}
```

- [ ] **Step 2: 写失败测试**

追加到 `proxy/tests/test_mappers.py`:
```python
from app.mappers import map_events, map_standings

EVENTS = json.loads((pathlib.Path(__file__).parent / "fixtures" / "af_events.json").read_text())
STANDINGS = json.loads((pathlib.Path(__file__).parent / "fixtures" / "af_standings.json").read_text())

def test_map_events():
    assert map_events(EVENTS) == [
        {"minute": 12, "team": "Brazil", "player": "Vinicius", "type": "Goal", "detail": "Normal Goal"},
        {"minute": 34, "team": "Germany", "player": "Kimmich", "type": "Card", "detail": "Yellow Card"},
    ]

def test_map_standings():
    out = map_standings(STANDINGS)
    assert out[0] == {"rank": 1, "team": "Mexico", "played": 2, "win": 2,
                      "draw": 0, "lose": 0, "goalsDiff": 3, "points": 6}
    assert len(out) == 2
```

- [ ] **Step 3: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_mappers.py -k "events or standings" -v`
Expected: FAIL — `ImportError: cannot import name 'map_events'`

- [ ] **Step 4: 实现(追加到 mappers.py)**

追加到 `proxy/app/mappers.py`:
```python
def map_events(data: dict) -> list[dict]:
    return [{
        "minute": e["time"]["elapsed"],
        "team": e["team"]["name"],
        "player": e.get("player", {}).get("name"),
        "type": e["type"],
        "detail": e.get("detail"),
    } for e in data.get("response", [])]

def map_standings(data: dict) -> list[dict]:
    resp = data.get("response", [])
    if not resp:
        return []
    groups = resp[0]["league"]["standings"]
    out = []
    for group in groups:
        for row in group:
            out.append({
                "rank": row["rank"],
                "team": row["team"]["name"],
                "played": row["all"]["played"],
                "win": row["all"]["win"],
                "draw": row["all"]["draw"],
                "lose": row["all"]["lose"],
                "goalsDiff": row["goalsDiff"],
                "points": row["points"],
            })
    return out
```

- [ ] **Step 5: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_mappers.py -v`
Expected: PASS (4 passed)

- [ ] **Step 6: 提交**

```bash
git add proxy/app/mappers.py proxy/tests/test_mappers.py proxy/tests/fixtures/
git commit -m "feat(proxy): event and standings mappers"
```

---

## Task 6: 赔率抓取解析器

**Files:**
- Create: `proxy/app/odds_scraper.py`
- Create: `proxy/tests/fixtures/odds_sample.html`
- Test: `proxy/tests/test_odds_scraper.py`

- [ ] **Step 1: 存一份赔率 HTML 样本**

`proxy/tests/fixtures/odds_sample.html`(模拟第三方页面最小结构):
```html
<table id="wdl"><tr>
  <td class="home">1.95</td><td class="draw">3.40</td><td class="away">3.75</td>
</tr></table>
```

- [ ] **Step 2: 写失败测试(纯解析, 不联网)**

`proxy/tests/test_odds_scraper.py`:
```python
import pathlib
from app.odds_scraper import parse_wdl

HTML = (pathlib.Path(__file__).parent / "fixtures" / "odds_sample.html").read_text()

def test_parse_wdl_extracts_three_odds():
    assert parse_wdl(HTML) == {"home": 1.95, "draw": 3.40, "away": 3.75}

def test_parse_wdl_missing_table_returns_none():
    assert parse_wdl("<html></html>") is None
```

- [ ] **Step 3: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_odds_scraper.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.odds_scraper'`

- [ ] **Step 4: 实现 odds_scraper.py**

`proxy/app/odds_scraper.py`:
```python
from selectolax.parser import HTMLParser

def parse_wdl(html: str) -> dict | None:
    tree = HTMLParser(html)
    table = tree.css_first("table#wdl")
    if table is None:
        return None
    def val(cls):
        node = table.css_first(f"td.{cls}")
        return float(node.text().strip()) if node else None
    result = {"home": val("home"), "draw": val("draw"), "away": val("away")}
    if any(v is None for v in result.values()):
        return None
    return result
```

- [ ] **Step 5: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_odds_scraper.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: 提交**

```bash
git add proxy/app/odds_scraper.py proxy/tests/test_odds_scraper.py proxy/tests/fixtures/odds_sample.html
git commit -m "feat(proxy): odds HTML parser with isolation test"
```

---

## Task 7: Service 编排 — 缓存 + 降级

**Files:**
- Create: `proxy/app/service.py`
- Test: `proxy/tests/test_service.py`

- [ ] **Step 1: 写失败测试**

`proxy/tests/test_service.py`:
```python
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
    # second call hits cache, no new fetch
    out2 = await cached_fetch(cache, "k", ttl=10, fetch=fetch)
    assert out2["stale"] is False
    assert len(calls) == 1

@pytest.mark.asyncio
async def test_falls_back_to_stale_on_error():
    cache = TTLCache(now=lambda: 100.0)
    cache.set("k", [{"id": 9}], ttl=5)
    cache._now = lambda: 200.0  # expired
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
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_service.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.service'`

- [ ] **Step 3: 实现 service.py**

`proxy/app/service.py`:
```python
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
```

- [ ] **Step 4: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_service.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: 提交**

```bash
git add proxy/app/service.py proxy/tests/test_service.py
git commit -m "feat(proxy): cached_fetch orchestration with stale fallback"
```

---

## Task 8: 端点接线 — /fixtures /live /results /standings

**Files:**
- Modify: `proxy/app/main.py`
- Test: `proxy/tests/test_endpoints.py`(追加)

- [ ] **Step 1: 写失败测试(mock 上游客户端)**

追加到 `proxy/tests/test_endpoints.py`:
```python
import json, pathlib
from unittest.mock import AsyncMock
import app.main as main

FX = json.loads((pathlib.Path(__file__).parent / "fixtures" / "af_fixtures.json").read_text())

def test_fixtures_endpoint_returns_mapped(monkeypatch):
    fake = AsyncMock(return_value=FX)
    monkeypatch.setattr(main.api, "get", fake)
    main.cache._store.clear()
    r = client.get("/fixtures")
    assert r.status_code == 200
    body = r.json()
    assert body["stale"] is False
    assert body["data"][0]["home"] == "Brazil"
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -k fixtures_endpoint -v`
Expected: FAIL — `AttributeError: module 'app.main' has no attribute 'api'`

- [ ] **Step 3: 实现端点(重写 main.py)**

`proxy/app/main.py`:
```python
from fastapi import FastAPI, HTTPException
import httpx
from app.config import settings, TTL
from app.cache import TTLCache
from app.upstream import ApiFootball
from app.service import cached_fetch
from app import mappers

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
```

- [ ] **Step 4: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -v`
Expected: PASS (全部)

- [ ] **Step 5: 提交**

```bash
git add proxy/app/main.py proxy/tests/test_endpoints.py
git commit -m "feat(proxy): wire fixtures/live/results/standings endpoints"
```

---

## Task 9: /odds 端点 + 降级占位

**Files:**
- Modify: `proxy/app/main.py`
- Modify: `proxy/app/odds_scraper.py`
- Test: `proxy/tests/test_endpoints.py`(追加)

- [ ] **Step 1: 写失败测试**

追加到 `proxy/tests/test_endpoints.py`:
```python
def test_odds_returns_null_when_scrape_fails(monkeypatch):
    async def boom(match_id):
        raise RuntimeError("scrape failed")
    monkeypatch.setattr(main, "fetch_odds", boom)
    main.cache._store.clear()
    r = client.get("/odds?matchId=101")
    assert r.status_code == 200
    assert r.json()["data"] is None

def test_odds_returns_parsed(monkeypatch):
    async def ok(match_id):
        return {"wdl": {"home": 1.95, "draw": 3.4, "away": 3.75}}
    monkeypatch.setattr(main, "fetch_odds", ok)
    main.cache._store.clear()
    r = client.get("/odds?matchId=101")
    assert r.json()["data"]["wdl"]["home"] == 1.95
```

- [ ] **Step 2: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -k odds -v`
Expected: FAIL — `AttributeError: module 'app.main' has no attribute 'fetch_odds'`

- [ ] **Step 3: 加抓取入口到 odds_scraper.py**

追加到 `proxy/app/odds_scraper.py`:
```python
import httpx

ODDS_URL = "https://odds.500.com/fenxi/shengfu-{match_id}.shtml"

async def fetch_odds(match_id: str) -> dict:
    async with httpx.AsyncClient(timeout=8.0) as c:
        r = await c.get(ODDS_URL.format(match_id=match_id))
        r.raise_for_status()
    wdl = parse_wdl(r.text)
    return {"wdl": wdl}
```

- [ ] **Step 4: 接 /odds 端点到 main.py**

追加到 `proxy/app/main.py`:
```python
from app.odds_scraper import fetch_odds

@app.get("/odds")
async def odds(matchId: str):
    async def fetch():
        return await fetch_odds(matchId)
    try:
        return await cached_fetch(cache, f"odds:{matchId}", TTL["odds"], fetch)
    except Exception:
        return {"data": None, "stale": True}
```

> 注: 测试 monkeypatch 的是 `main.fetch_odds`, 故端点内调用须经模块属性。把上面 `fetch()` 改为 `return await fetch_odds(matchId)` 已满足(已在 main 命名空间导入)。

- [ ] **Step 5: 运行确认通过**

Run: `cd proxy && python -m pytest tests/test_endpoints.py -k odds -v`
Expected: PASS (2 passed)

- [ ] **Step 6: 提交**

```bash
git add proxy/app/main.py proxy/app/odds_scraper.py proxy/tests/test_endpoints.py
git commit -m "feat(proxy): odds endpoint with null fallback on scrape failure"
```

---

## Task 10: 对阵图端点 /bracket

**Files:**
- Modify: `proxy/app/mappers.py`
- Modify: `proxy/app/main.py`
- Create: `proxy/tests/fixtures/af_ko.json`
- Test: `proxy/tests/test_mappers.py`(追加)

- [ ] **Step 1: 存淘汰赛样本**

`proxy/tests/fixtures/af_ko.json`:
```json
{"response": [
  {"fixture": {"id": 201, "status": {"short": "FT"}},
   "league": {"round": "Round of 16"},
   "teams": {"home": {"name": "Brazil"}, "away": {"name": "Korea"}},
   "goals": {"home": 3, "away": 0}},
  {"fixture": {"id": 202, "status": {"short": "NS"}},
   "league": {"round": "Quarter-finals"},
   "teams": {"home": {"name": "France"}, "away": {"name": "Argentina"}},
   "goals": {"home": null, "away": null}}
]}
```

- [ ] **Step 2: 写失败测试**

追加到 `proxy/tests/test_mappers.py`:
```python
from app.mappers import map_bracket

KO = json.loads((pathlib.Path(__file__).parent / "fixtures" / "af_ko.json").read_text())

def test_map_bracket_groups_by_round():
    out = map_bracket(KO)
    assert out["Round of 16"][0]["home"] == "Brazil"
    assert out["Round of 16"][0]["homeScore"] == 3
    assert out["Quarter-finals"][0]["homeScore"] is None
```

- [ ] **Step 3: 运行确认失败**

Run: `cd proxy && python -m pytest tests/test_mappers.py -k bracket -v`
Expected: FAIL — `ImportError: cannot import name 'map_bracket'`

- [ ] **Step 4: 实现 map_bracket(追加 mappers.py)**

追加到 `proxy/app/mappers.py`:
```python
def map_bracket(data: dict) -> dict:
    rounds: dict[str, list] = {}
    for item in data.get("response", []):
        rnd = item.get("league", {}).get("round", "Unknown")
        rounds.setdefault(rnd, []).append({
            "id": item["fixture"]["id"],
            "home": item["teams"]["home"]["name"],
            "away": item["teams"]["away"]["name"],
            "homeScore": item["goals"]["home"],
            "awayScore": item["goals"]["away"],
        })
    return rounds
```

- [ ] **Step 5: 接 /bracket 端点(追加 main.py)**

追加到 `proxy/app/main.py`:
```python
@app.get("/bracket")
async def bracket():
    async def fetch():
        raw = await api.get("/fixtures", params={**LEAGUE})
        return mappers.map_bracket(raw)
    try:
        return await cached_fetch(cache, "bracket", TTL["bracket"], fetch)
    except httpx.HTTPStatusError:
        raise HTTPException(status_code=502, detail="upstream unavailable")
```

- [ ] **Step 6: 运行确认通过**

Run: `cd proxy && python -m pytest tests/ -v`
Expected: PASS (全部)

- [ ] **Step 7: 提交**

```bash
git add proxy/app/mappers.py proxy/app/main.py proxy/tests/
git commit -m "feat(proxy): bracket endpoint grouped by knockout round"
```

---

## Task 11: README + 本地运行验证

**Files:**
- Create: `proxy/README.md`

- [ ] **Step 1: 写 README**

`proxy/README.md`:
```markdown
# 世界杯代理服务

## 运行
\`\`\`
cd proxy
python -m venv .venv && .venv\Scripts\activate   # Windows
pip install -r requirements.txt
copy .env.example .env   # 填入 API-Football 密钥
uvicorn app.main:app --reload --port 8000
\`\`\`

## 端点
- GET /health
- GET /fixtures · /live · /results · /standings · /bracket
- GET /odds?matchId=<id>

返回形如 `{"data": ..., "stale": false}`。

## 测试
\`\`\`
python -m pytest tests/ -v
\`\`\`
```

- [ ] **Step 2: 跑全量测试**

Run: `cd proxy && python -m pytest tests/ -v`
Expected: PASS (全部绿)

- [ ] **Step 3: 手动冒烟(可选, 需真实密钥)**

填好 `.env` 后:
Run: `cd proxy && uvicorn app.main:app --port 8000`
另开终端: `curl http://localhost:8000/health`
Expected: `{"status":"ok"}`

- [ ] **Step 4: 提交**

```bash
git add proxy/README.md
git commit -m "docs(proxy): run and endpoint guide"
```

---

## Self-Review 结果

- **Spec 覆盖:** 5 端点(赛程/实况/结果/积分/对阵)+ 赔率端点 + 缓存 TTL + stale 降级 + 赔率抓取隔离测试 + 抓取失败占位, 均有对应 Task。✅
- **占位扫描:** 无 TBD/TODO; 每步含真实代码与命令。✅
- **类型一致性:** `cached_fetch(cache, key, ttl, fetch)` 全程签名一致; `map_fixtures/map_events/map_standings/map_bracket` 命名前后一致; `fetch_odds(match_id)` 一致。✅
- **未在本计划:** Flutter App(计划 2)、真实赔率站点精确选择器(抓取测试用样本 HTML 隔离, 上线时按真实页面调 `parse_wdl` 选择器)。
