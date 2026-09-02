import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from nova.api.routers import chat, facts, health, reasoning

logging.basicConfig(level=logging.WARNING)

app = FastAPI(title="Nova API")

# TODO: narrow allow_origins once the Flutter app's release/dev URLs are fixed.
# Wide open for now since auth isn't enforced yet either - tighten both together.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(chat.router)
app.include_router(facts.router)
app.include_router(reasoning.router)