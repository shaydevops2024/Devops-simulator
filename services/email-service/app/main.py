from fastapi import FastAPI

app = FastAPI()

@app.post("/send")
def send():
    return {"sent": True}

