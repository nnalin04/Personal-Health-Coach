"""
Anthropic Claude client — optional paid fallback, NOT used in default routing.

Only activate when Gemini free tier is exhausted for REPORT tasks or when
very high reasoning quality is required. Cost: ~$0.80/M input tokens.

Implements BaseAIClient. Raises ValueError on init if key is missing.
3-attempt retry with exponential backoff. Raises AIError on final failure.
"""
import json
import logging
import os
import time

from app.ai.base_client import BaseAIClient, AIError

logger = logging.getLogger(__name__)

_MAX_ATTEMPTS = 3
_BASE_WAIT_S  = 1.0  # doubles: 1s, 2s, 4s
_MAX_TOKENS   = 4096


def _strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1] if len(parts) > 1 else text
        if text.startswith("json"):
            text = text[4:]
    return text.strip()


class ClaudeClient(BaseAIClient):
    """Anthropic Claude provider implementing BaseAIClient."""

    def __init__(self) -> None:
        api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
        if not api_key:
            raise ValueError(
                "ANTHROPIC_API_KEY environment variable is not set or is empty."
            )
        import anthropic as anthropic_sdk
        self._anthropic = anthropic_sdk
        self._client = anthropic_sdk.Anthropic(api_key=api_key)
        self.model = os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001")
        logger.info("ClaudeClient initialised with model=%s", self.model)

    # ── BaseAIClient implementation ───────────────────────────────────────────

    def generate_json(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
        temperature: float = 0.2,
    ) -> dict:
        """Call Claude and return a parsed JSON dict."""
        last_exc: Exception | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                resp = self._client.messages.create(
                    model=self.model,
                    max_tokens=_MAX_TOKENS,
                    temperature=temperature,
                    system=system_prompt,
                    messages=[{"role": "user", "content": user_prompt}],
                )
                raw = resp.content[0].text if resp.content else ""
                cleaned = _strip_fences(raw)
                try:
                    return json.loads(cleaned)
                except json.JSONDecodeError as exc:
                    raise AIError(f"Claude response is not valid JSON: {exc}") from exc

            except AIError:
                raise

            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_ATTEMPTS:
                    wait = _BASE_WAIT_S * (2 ** (attempt - 1))
                    logger.warning(
                        "Claude attempt %d/%d failed (%s). Retrying in %.1fs…",
                        attempt, _MAX_ATTEMPTS, exc, wait,
                    )
                    time.sleep(wait)
                else:
                    logger.error(
                        "Claude failed after %d attempts: %s",
                        _MAX_ATTEMPTS, exc, exc_info=True,
                    )

        raise AIError(f"Claude unavailable after {_MAX_ATTEMPTS} attempts") from last_exc

    def generate_text(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
    ) -> str:
        """Call Claude and return plain text."""
        last_exc: Exception | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                resp = self._client.messages.create(
                    model=self.model,
                    max_tokens=_MAX_TOKENS,
                    system=system_prompt,
                    messages=[{"role": "user", "content": user_prompt}],
                )
                return resp.content[0].text if resp.content else ""

            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_ATTEMPTS:
                    wait = _BASE_WAIT_S * (2 ** (attempt - 1))
                    logger.warning(
                        "Claude text attempt %d/%d failed (%s). Retrying in %.1fs…",
                        attempt, _MAX_ATTEMPTS, exc, wait,
                    )
                    time.sleep(wait)
                else:
                    logger.error(
                        "Claude text failed after %d attempts: %s",
                        _MAX_ATTEMPTS, exc, exc_info=True,
                    )

        raise AIError(f"Claude unavailable after {_MAX_ATTEMPTS} attempts") from last_exc
