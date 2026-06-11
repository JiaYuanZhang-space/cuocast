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
