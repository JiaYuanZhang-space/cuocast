from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    api_football_key: str = ""
    api_football_base: str = "https://v3.football.api-sports.io"
    wc_league_id: int = 1
    wc_season: int = 2026

TTL = {
    "live": 30,
    "fixtures": 3600,
    "results": 21600,
    "standings": 3600,
    "bracket": 3600,
    "odds": 300,
}

settings = Settings()
