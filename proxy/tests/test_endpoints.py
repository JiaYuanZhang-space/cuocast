import json, pathlib
from unittest.mock import AsyncMock
from fastapi.testclient import TestClient
from app.main import app
import app.main as main

client = TestClient(app)

def test_health_returns_ok():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}

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
