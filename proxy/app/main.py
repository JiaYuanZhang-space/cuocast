from fastapi import FastAPI

app = FastAPI(title="WorldCup Proxy")

@app.get("/health")
def health():
    return {"status": "ok"}
