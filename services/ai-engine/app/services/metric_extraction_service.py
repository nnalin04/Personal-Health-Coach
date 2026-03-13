import json
import logging
from datetime import date
from app.ai.gemini_client import GeminiClient
from app.schemas.metrics import ExtractMetricsResponse, ExtractedMetric

logger = logging.getLogger(__name__)


class MetricExtractionService:
    def __init__(self) -> None:
        self.gemini_client = GeminiClient()

    def extract_metrics(self, text: str) -> ExtractMetricsResponse:
        system_prompt = (
            "You are a health data extraction expert. "
            "Extract health metrics (weight, steps, heart rate, etc.) from the user's text. "
            "For each metric, identify the numeric value, the metric name, and the date it refers to. "
            f"Note: today's date is {date.today().isoformat()}. "
            "Return a JSON list of objects with keys: metric, value, date (ISO 8601), and unit."
        )
        user_prompt = f"Text: {text}"

        try:
            output = self.gemini_client.generate_json(system_prompt, user_prompt)
            # Handle both list and dict wrapped in 'metrics'
            metrics_data = output if isinstance(output, list) else output.get("metrics", [])
            
            metrics = [
                ExtractedMetric(
                    metric=m.get("metric", "unknown"),
                    value=float(m.get("value", 0)),
                    date=m.get("date", date.today().isoformat()),
                    unit=m.get("unit")
                )
                for m in metrics_data
            ]
            return ExtractMetricsResponse(metrics=metrics, raw_text=text)
        except Exception as e:
            logger.exception("Gemini metric extraction failed — using regex fallback")
            # Fallback for simple weight extraction if LLM fails
            import re
            weight_match = re.search(r"(weight|weigh)\s*(?:is|at)?\s*(\d+(?:\.\d+)?)\s*(kg|kilos|lbs)?", text, re.I)
            if weight_match:
                return ExtractMetricsResponse(
                    metrics=[ExtractedMetric(
                        metric="weight",
                        value=float(weight_match.group(2)),
                        date=date.today().isoformat(),
                        unit=weight_match.group(3)
                    )],
                    raw_text=text
                )
            return ExtractMetricsResponse(metrics=[], raw_text=text)
