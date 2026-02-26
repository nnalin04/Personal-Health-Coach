from pydantic import BaseModel, Field
from typing import Any
from pydantic import model_validator


class AnalyzeHealthRequest(BaseModel):
    summary: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode='before')
    @classmethod
    def wrap_raw_summary(cls, value: Any) -> Any:
        # Backward-compatible: accept either {"summary": {...}} or raw summary JSON.
        if isinstance(value, dict) and 'summary' not in value:
            return {'summary': value}
        return value


class AnalyzeHealthResponse(BaseModel):
    dietSuggestions: list[str]
    trainingSuggestions: list[str]
    recoverySuggestions: list[str]
    medicalAwarenessNotes: list[str]
    disclaimer: str
