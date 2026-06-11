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
            "homeScore": item["goals"]["home"],
            "awayScore": item["goals"]["away"],
        })
    return out
