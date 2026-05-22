import base64
import json
import os
from contextlib import asynccontextmanager

import firebase_admin
from fastapi import FastAPI
from firebase_admin import credentials

from routers import chat, memory, mem0


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Support multiple credential formats:
    # 1. FIREBASE_SERVICE_ACCOUNT_BASE64 — base64-encoded JSON (Railway preferred)
    # 2. FIREBASE_SERVICE_ACCOUNT — raw JSON string
    # 3. FIREBASE_SERVICE_ACCOUNT_PATH / serviceAccountKey.json — file path (local dev)
    encoded = os.environ.get("FIREBASE_SERVICE_ACCOUNT_BASE64")
    raw_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
    if encoded:
        service_account_info = json.loads(base64.b64decode(encoded).decode())
        cred = credentials.Certificate(service_account_info)
    elif raw_json:
        service_account_info = json.loads(raw_json)
        cred = credentials.Certificate(service_account_info)
    else:
        path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "serviceAccountKey.json")
        cred = credentials.Certificate(path)
    firebase_admin.initialize_app(cred)
    yield


app = FastAPI(title="Hermes Agent Service", version="1.0.0", lifespan=lifespan)
app.include_router(chat.router, prefix="/api/v1")
app.include_router(memory.router, prefix="/api/v1/memory", tags=["memory"])
app.include_router(mem0.router, prefix="/api/v1/mem0", tags=["mem0"])


@app.get("/health")
async def health():
    return {"status": "ok"}
