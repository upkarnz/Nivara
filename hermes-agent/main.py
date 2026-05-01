import base64
import json
import os
from contextlib import asynccontextmanager

import firebase_admin
from fastapi import FastAPI
from firebase_admin import credentials

from routers import chat


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Support base64-encoded JSON in env var (Railway/production) or a local file (dev)
    encoded = os.environ.get("FIREBASE_SERVICE_ACCOUNT_BASE64")
    if encoded:
        service_account_info = json.loads(base64.b64decode(encoded).decode())
        cred = credentials.Certificate(service_account_info)
    else:
        path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "serviceAccountKey.json")
        cred = credentials.Certificate(path)
    firebase_admin.initialize_app(cred)
    yield


app = FastAPI(title="Hermes Agent Service", version="1.0.0", lifespan=lifespan)
app.include_router(chat.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
