def map_fixtures(data: dict) -> list[dict]:
    out = []
    for item in data.get("response", []):
        fx = item["fixture"]
        out.append({
            "id": fx["id"],
            "kickoff": fx["date"],
            "status": fx["status"]["short"],
            "minute": fx["status"].get("elapsed"),
            "venue": fx.get("venue", {}).get("name"),
            "round": item.get("league", {}).get("round"),
            "home": item["teams"]["home"]["name"],
            "away": item["teams"]["away"]["name"],
            "homeScore": (item.get("goals") or {}).get("home"),
            "awayScore": (item.get("goals") or {}).get("away"),
        })
    return out


def map_events(data: dict) -> list[dict]:
    return [{
        "minute": e["time"]["elapsed"],
        "team": e["team"]["name"],
        "player": e.get("player", {}).get("name"),
        "type": e["type"],
        "detail": e.get("detail"),
    } for e in data.get("response", [])]


def map_standings(data: dict) -> list[dict]:
    resp = data.get("response", [])
    if not resp:
        return []
    groups = resp[0]["league"]["standings"]
    out = []
    for group in groups:
        for row in group:
            out.append({
                "rank": row["rank"],
                "team": row["team"]["name"],
                "played": row["all"]["played"],
                "win": row["all"]["win"],
                "draw": row["all"]["draw"],
                "lose": row["all"]["lose"],
                "goalsDiff": row["goalsDiff"],
                "points": row["points"],
            })
    return out


def map_bracket(data: dict) -> dict:
    rounds: dict[str, list] = {}
    for item in data.get("response", []):
        rnd = item.get("league", {}).get("round", "Unknown")
        rounds.setdefault(rnd, []).append({
            "id": item["fixture"]["id"],
            "home": item["teams"]["home"]["name"],
            "away": item["teams"]["away"]["name"],
            "homeScore": (item.get("goals") or {}).get("home"),
            "awayScore": (item.get("goals") or {}).get("away"),
        })
    return rounds
