import logging

from fastapi import FastAPI

from nova.api.routers import chat, facts, health, reasoning

logging.basicConfig(level=logging.WARNING)

app = FastAPI(title="Nova API")

app.include_router(health.router)
app.include_router(chat.router)
app.include_router(facts.router)
app.include_router(reasoning.router)