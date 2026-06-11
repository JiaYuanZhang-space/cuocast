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
