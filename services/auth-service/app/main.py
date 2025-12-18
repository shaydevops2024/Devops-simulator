from fastapi import FastAPI

app = FastAPI()

@app.post("/auth/login")
def login():
    return {"token": "dummy"}

@app.post("/auth/register")
def register():
    return {"ok": True}

