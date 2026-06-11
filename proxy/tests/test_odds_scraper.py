import pathlib
from app.odds_scraper import parse_wdl

HTML = (pathlib.Path(__file__).parent / "fixtures" / "odds_sample.html").read_text()

def test_parse_wdl_extracts_three_odds():
    assert parse_wdl(HTML) == {"home": 1.95, "draw": 3.40, "away": 3.75}

def test_parse_wdl_missing_table_returns_none():
    assert parse_wdl("<html></html>") is None
