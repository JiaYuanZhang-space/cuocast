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
