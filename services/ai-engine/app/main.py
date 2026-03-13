from app.logging_config import setup_logging

# Configure JSON logging before anything else imports logging
setup_logging()

import os
import time
import logging
from collections import defaultdict
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.routers.health_router import router as health_router
from app.routers.nutrient_router import router as nutrient_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start RabbitMQ consumers (degrades gracefully if RabbitMQ is absent)
    from app.consumers.rabbitmq_consumer import start_consumers
    await start_consumers()
    yield


app = FastAPI(title="Health OS AI Engine", version="2.0.0", lifespan=lifespan)

# Simple in-memory rate limiter: 10 Gemini requests per minute per caller IP.
# Disabled when GEMINI_API_KEY is absent (test / offline mode).
_RATE_LIMIT = 10
_WINDOW_SECONDS = 60
_request_log: dict[str, list[float]] = defaultdict(list)
_rate_limiting_enabled = bool(os.getenv("GEMINI_API_KEY", "").strip())


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    # Only rate-limit Gemini-backed endpoints in production (key present)
    gemini_paths = {"/analyze-health", "/parse-medical-report", "/extract-metrics",
                    "/food/analyze-nutrients", "/nutrient/recommendations"}
    if _rate_limiting_enabled and request.url.path in gemini_paths:
        client_ip = request.client.host if request.client else "unknown"
        now = time.monotonic()
        window_start = now - _WINDOW_SECONDS
        hits = _request_log[client_ip]
        # Evict old timestamps
        _request_log[client_ip] = [t for t in hits if t > window_start]
        if len(_request_log[client_ip]) >= _RATE_LIMIT:
            logger.warning("Rate limit exceeded for %s on %s", client_ip, request.url.path)
            return JSONResponse(status_code=429, content={"detail": "Too many requests. Please try again later."})
        _request_log[client_ip].append(now)
    return await call_next(request)


app.include_router(health_router)
app.include_router(nutrient_router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
