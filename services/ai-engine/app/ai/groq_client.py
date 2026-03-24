"""
Groq AI client — wraps the groq Python SDK.

Two model tiers:
  Text:   llama-3.3-70b-versatile  (fast, cheap, great for structured output)
  Vision: llama-3.2-11b-vision-preview  (free-tier food/receipt image analysis)

Free tier: 14,400 requests/day across all Groq models.
3-attempt retry with exponential backoff. Raises AIError on final failure.
"""
import base64
import json
import logging
import os
import time

from app.ai.base_client import BaseAIClient, AIError

logger = logging.getLogger(__name__)

_MAX_ATTEMPTS = 3
_BASE_WAIT_S  = 1.0  # doubles: 1s, 2s, 4s


def _strip_fences(text: str) -> str:
    """Strip markdown code fences from a response string."""
    text = text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        # parts[1] is the content between first pair of fences
        text = parts[1] if len(parts) > 1 else text
        if text.startswith("json"):
            text = text[4:]
    return text.strip()


class GroqClient(BaseAIClient):
    """Groq provider implementing BaseAIClient."""

    def __init__(self) -> None:
        api_key = os.getenv("GROQ_API_KEY", "").strip()
        if not api_key:
            raise ValueError(
                "GROQ_API_KEY environment variable is not set or is empty."
            )
        import groq as groq_sdk
        self._groq = groq_sdk
        self._client = groq_sdk.Groq(api_key=api_key)
        self.text_model   = os.getenv("GROQ_TEXT_MODEL",   "llama-3.3-70b-versatile")
        self.vision_model = os.getenv("GROQ_VISION_MODEL", "llama-3.2-11b-vision-preview")
        logger.info(
            "GroqClient initialised text_model=%s vision_model=%s",
            self.text_model, self.vision_model,
        )

    # ── BaseAIClient implementation ───────────────────────────────────────────

    def generate_json(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
        temperature: float = 0.2,
    ) -> dict:
        """Call Groq text model and return a parsed JSON dict."""
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": user_prompt},
        ]
        return self._call_with_retry(messages, self.text_model, temperature)

    def generate_text(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
    ) -> str:
        """Call Groq text model and return plain text."""
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": user_prompt},
        ]
        last_exc: Exception | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                resp = self._client.chat.completions.create(
                    model=self.text_model,
                    messages=messages,
                    temperature=temperature if (temperature := 0.2) else 0.2,
                )
                return resp.choices[0].message.content or ""
            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_ATTEMPTS:
                    wait = _BASE_WAIT_S * (2 ** (attempt - 1))
                    logger.warning(
                        "Groq text attempt %d/%d failed (%s). Retrying in %.1fs…",
                        attempt, _MAX_ATTEMPTS, exc, wait,
                    )
                    time.sleep(wait)
                else:
                    logger.error("Groq text failed after %d attempts: %s", _MAX_ATTEMPTS, exc, exc_info=True)
        raise AIError(f"Groq unavailable after {_MAX_ATTEMPTS} attempts") from last_exc

    # ── Vision extension ──────────────────────────────────────────────────────

    def generate_vision_json(
        self,
        system_prompt: str,
        user_prompt: str,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        temperature: float = 0.2,
    ) -> dict:
        """
        Call Groq vision model with an image encoded as a base64 data-URL.

        The image is embedded in the user message content array per the
        OpenAI-compatible multimodal messages spec that Groq supports.
        """
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        data_url = f"data:{mime_type};base64,{b64}"

        messages = [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text",      "text": user_prompt},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ]
        return self._call_with_retry(messages, self.vision_model, temperature)

    # ── internal ──────────────────────────────────────────────────────────────

    def _call_with_retry(self, messages: list, model: str, temperature: float) -> dict:
        last_exc: Exception | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                resp = self._client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=temperature,
                )
                raw = resp.choices[0].message.content or ""
                cleaned = _strip_fences(raw)
                try:
                    return json.loads(cleaned)
                except json.JSONDecodeError as exc:
                    raise AIError(f"Groq response is not valid JSON: {exc}") from exc

            except AIError:
                raise  # JSON parse failures won't improve on retry

            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_ATTEMPTS:
                    wait = _BASE_WAIT_S * (2 ** (attempt - 1))
                    logger.warning(
                        "Groq attempt %d/%d failed (%s). Retrying in %.1fs…",
                        attempt, _MAX_ATTEMPTS, exc, wait,
                    )
                    time.sleep(wait)
                else:
                    logger.error(
                        "Groq failed after %d attempts: %s",
                        _MAX_ATTEMPTS, exc, exc_info=True,
                    )

        raise AIError(f"Groq unavailable after {_MAX_ATTEMPTS} attempts") from last_exc
