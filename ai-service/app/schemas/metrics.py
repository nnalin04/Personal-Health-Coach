from pydantic import BaseModel
from typing import Optional

class ExtractMetricsRequest(BaseModel):
    text: str

class ExtractedMetric(BaseModel):
    metric: str
    value: float
    date: str
    unit: Optional[str] = None

class ExtractMetricsResponse(BaseModel):
    metrics: list[ExtractedMetric]
    raw_text: str
