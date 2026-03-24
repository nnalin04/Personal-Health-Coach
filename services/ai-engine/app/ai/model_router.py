"""
Model Router — selects the most cost-effective AI client for each task type.

Routing table (first available provider wins):
  FOOD    → GroqClient (vision)  → GeminiClient
  REPORT  → GeminiClient         → GroqClient (text)
  RECEIPT → GroqClient (vision)  → GeminiClient
  TEXT    → GroqClient (text)    → GeminiClient
  RAG     → GeminiClient (only — embedding consistency with text-embedding-004)

All providers fall back to GeminiClient which is always required.
Clients are lazy singletons — instantiated once and cached.
"""
import logging
from typing import Optional

from app.ai.base_client import BaseAIClient

logger = logging.getLogger(__name__)

# ── singletons ────────────────────────────────────────────────────────────────

_groq_client:   Optional["GroqClient"]   = None   # type: ignore[name-defined]
_gemini_client: Optional["GeminiClient"] = None   # type: ignore[name-defined]
_groq_init_failed: bool = False  # cache init failure so we don't retry on every call


def _reset_singletons() -> None:
    """Reset cached singletons — used by tests to avoid state leakage."""
    global _groq_client, _gemini_client, _groq_init_failed
    _groq_client = None
    _gemini_client = None
    _groq_init_failed = False


# ── private helpers ───────────────────────────────────────────────────────────

def _get_gemini() -> "GeminiClient":  # type: ignore[name-defined]
    global _gemini_client
    if _gemini_client is None:
        from app.ai.gemini_client import GeminiClient
        _gemini_client = GeminiClient()   # raises ValueError if key missing — intentional
    return _gemini_client


def _get_groq() -> Optional["GroqClient"]:  # type: ignore[name-defined]
    global _groq_client, _groq_init_failed
    if _groq_init_failed:
        return None
    if _groq_client is None:
        try:
            from app.ai.groq_client import GroqClient
            _groq_client = GroqClient()
        except ValueError as exc:
            logger.info("GROQ_API_KEY not set — Groq disabled: %s", exc)
            _groq_init_failed = True
            return None
        except Exception as exc:
            logger.warning("Groq init failed (%s) — falling back to Gemini", exc)
            _groq_init_failed = True
            return None
    return _groq_client


# ── public API ────────────────────────────────────────────────────────────────

def get_client(task_type: str) -> BaseAIClient:
    """
    Return the best available text client for the given task type.

    REPORT → Gemini (best clinical reasoning)
    TEXT   → Groq → Gemini fallback
    RAG    → Gemini only (embedding consistency)
    Other  → Groq → Gemini fallback
    """
    task = (task_type or "").upper()

    if task in ("REPORT", "RAG"):
        # Always Gemini for REPORT (clinical accuracy) and RAG (embedding consistency)
        return _get_gemini()

    if task == "TEXT":
        groq = _get_groq()
        if groq is not None:
            return groq
        logger.info("GROQ_API_KEY not set — using Gemini for %s", task)
        return _get_gemini()

    # Default: try Groq, fall back to Gemini
    groq = _get_groq()
    if groq is not None:
        return groq
    logger.info("GROQ_API_KEY not set — using Gemini for %s", task)
    return _get_gemini()


def get_vision_client(task_type: str) -> BaseAIClient:
    """
    Return the best vision-capable client for FOOD or RECEIPT tasks.

    Returns GroqClient if GROQ_API_KEY is set (uses vision model internally),
    otherwise GeminiClient.
    """
    task = (task_type or "").upper()
    groq = _get_groq()
    if groq is not None:
        return groq
    logger.info("GROQ_API_KEY not set — using Gemini for %s", task)
    return _get_gemini()
