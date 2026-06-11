from fastapi.testclient import TestClient
from app.main import app

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
