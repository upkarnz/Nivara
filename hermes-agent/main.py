from contextlib import asynccontextmanager
from fastapi import FastAPI
import firebase_admin
from firebase_admin import credentials
from routers import chat


@asynccontextmanager
async def lifespan(app: FastAPI):
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    yield


app = FastAPI(title="Hermes Agent Service", version="1.0.0", lifespan=lifespan)
app.include_router(chat.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
