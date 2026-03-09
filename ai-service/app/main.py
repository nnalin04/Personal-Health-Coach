from app.logging_config import setup_logging

# Configure JSON logging before anything else imports logging
setup_logging()

from fastapi import FastAPI
from app.routers.health_router import router as health_router
from app.routers.nutrient_router import router as nutrient_router

app = FastAPI(title="Personal Health AI Service", version="0.1.0")
app.include_router(health_router)
app.include_router(nutrient_router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
