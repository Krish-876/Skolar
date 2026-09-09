import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import traceback

from nova.api.routers import chat, facts, health, proposals, reasoning

logging.basicConfig(level=logging.WARNING)

app = FastAPI(title="Nova API")

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "detail": f"{str(exc)}\n\nTraceback:\n{traceback.format_exc()}"
        }
    )

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
app.include_router(proposals.router)