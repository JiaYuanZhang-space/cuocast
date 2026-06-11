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
