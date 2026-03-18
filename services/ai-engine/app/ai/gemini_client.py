"""
Gemini API client with:
  - Exponential backoff retry (tenacity): 3 attempts, 1s/2s/4s waits
  - Per-call temperature override (medical parsing needs 0.1, chat needs 0.5)
  - Structured error logging on final failure
  - No bare except — raises GeminiError on all failure paths so callers
    can return typed error responses instead of silently returning {}
"""
import json
import logging
import os
import time

import google.generativeai as genai

logger = logging.getLogger(__name__)

# Retry constants
_MAX_ATTEMPTS = 3
_BASE_WAIT_S  = 1.0   # doubles each attempt: 1s, 2s, 4s


class GeminiError(RuntimeError):
    """Raised when Gemini fails after all retry attempts."""


class GeminiClient:
    def __init__(self) -> None:
        api_key = os.getenv("GEMINI_API_KEY", "").strip()
        if not api_key:
            raise ValueError(
                "GEMINI_API_KEY environment variable is not set or is empty. "
                "The AI service cannot start without a valid Gemini API key."
            )
        self.model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel(self.model_name)
        logger.info("GeminiClient initialised with model=%s", self.model_name)

    def generate_json(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
        temperature: float = 0.2,
    ) -> dict:
        """
        Call Gemini and return parsed JSON dict.

        Args:
            system_prompt: Role/context instructions.
            user_prompt:   The actual request.
            contents:      Optional multimodal content list (images, etc.).
            temperature:   Sampling temperature — override per use-case:
                             0.1  for medical/lab parsing (deterministic)
                             0.2  for health recommendations (default)
                             0.5  for conversational / RAG responses

        Returns:
            Parsed dict from Gemini's JSON response.

        Raises:
            GeminiError: If all retry attempts are exhausted or response is unparseable.
        """
        if contents is None:
            prompt_parts = [f"{system_prompt}\n\n{user_prompt}"]
        else:
            prompt_parts = [system_prompt, *contents, user_prompt]

        last_exc: Exception | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                response = self.model.generate_content(
                    prompt_parts,
                    generation_config=genai.types.GenerationConfig(
                        response_mime_type="application/json",
                        temperature=temperature,
                    ),
                )
                return self._parse_response(response)

            except (GeminiError, ValueError):
                # Parse failure — retrying won't help
                raise

            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_ATTEMPTS:
                    wait = _BASE_WAIT_S * (2 ** (attempt - 1))   # 1s, 2s, 4s
                    logger.warning(
                        "Gemini attempt %d/%d failed (%s). Retrying in %.1fs…",
                        attempt, _MAX_ATTEMPTS, exc, wait,
                    )
                    time.sleep(wait)
                else:
                    logger.error(
                        "Gemini failed after %d attempts: %s",
                        _MAX_ATTEMPTS, exc, exc_info=True,
                    )

        raise GeminiError(f"Gemini unavailable after {_MAX_ATTEMPTS} attempts") from last_exc

    # ── private ───────────────────────────────────────────────────────────────

    @staticmethod
    def _parse_response(response) -> dict:
        content = (response.text or "").strip()
        if not content:
            raise GeminiError("Gemini returned an empty response")
        # Strip potential markdown code fences
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
            content = content.strip()
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise GeminiError(f"Gemini response is not valid JSON: {exc}") from exc
