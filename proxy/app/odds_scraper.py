import httpx
from selectolax.parser import HTMLParser

ODDS_URL = "https://odds.500.com/fenxi/shengfu-{match_id}.shtml"

async def fetch_odds(match_id: str) -> dict:
    async with httpx.AsyncClient(timeout=8.0) as c:
        r = await c.get(ODDS_URL.format(match_id=match_id))
        r.raise_for_status()
        wdl = parse_wdl(r.text)
    return {"wdl": wdl}

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
