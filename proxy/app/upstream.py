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
