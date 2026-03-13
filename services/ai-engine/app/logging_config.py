"""
Structured JSON logging for the Personal Health Coach AI service.

Usage:
    from app.logging_config import setup_logging
    setup_logging()  # call once at app startup

Emits one JSON object per line:
    {"time": "2026-03-05T10:00:00Z", "level": "INFO", "logger": "...", "message": "..."}
"""

import json
import logging
import sys
from datetime import datetime, timezone


class JsonFormatter(logging.Formatter):
    """Format log records as single-line JSON objects."""

    def format(self, record: logging.LogRecord) -> str:
        log_object: dict = {
            "time": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            log_object["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_object)


def setup_logging(level: str = "INFO") -> None:
    """Configure root logger and uvicorn loggers to emit JSON."""
    json_handler = logging.StreamHandler(sys.stdout)
    json_handler.setFormatter(JsonFormatter())

    root = logging.getLogger()
    root.setLevel(level)
    # Remove any existing handlers to avoid duplicate output
    root.handlers.clear()
    root.addHandler(json_handler)

    # Apply JSON formatter to uvicorn loggers as well
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"):
        logger = logging.getLogger(name)
        logger.handlers.clear()
        logger.propagate = True
