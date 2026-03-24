"""
Base AI client interface — all providers (Gemini, Groq, Claude) implement this.
Callers program to this interface; model_router decides which concrete client to return.
"""
from abc import ABC, abstractmethod


class AIError(RuntimeError):
    """Raised when an AI provider fails after all retry attempts."""


class BaseAIClient(ABC):

    @abstractmethod
    def generate_json(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
        temperature: float = 0.2,
    ) -> dict:
        """
        Call the AI provider and return a parsed JSON dict.

        Args:
            system_prompt: Role/context instructions for the model.
            user_prompt:   The actual request text.
            contents:      Optional multimodal content (images, PDFs) as
                           [{"mime_type": "image/jpeg", "data": <bytes>}].
            temperature:   Sampling temperature (0.1 = deterministic, 0.5 = creative).

        Returns:
            Parsed dict from the model's JSON response.

        Raises:
            AIError: If the provider fails after all retries or returns unparseable JSON.
        """

    @abstractmethod
    def generate_text(
        self,
        system_prompt: str,
        user_prompt: str,
        contents: list | None = None,
    ) -> str:
        """
        Call the AI provider and return plain text.

        Raises:
            AIError: On provider failure.
        """
