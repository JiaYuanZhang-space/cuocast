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
