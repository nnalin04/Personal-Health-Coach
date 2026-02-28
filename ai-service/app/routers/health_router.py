from fastapi import APIRouter
from app.schemas.health import AnalyzeHealthRequest, AnalyzeHealthResponse
from app.schemas.medical import ParseMedicalReportRequest, ParseMedicalReportResponse
from app.schemas.metrics import ExtractMetricsRequest, ExtractMetricsResponse
from app.services.recommendation_service import RecommendationService
from app.services.report_parser_service import ReportParserService
from app.services.metric_extraction_service import MetricExtractionService

router = APIRouter()
recommendation_service = RecommendationService()
report_parser_service = ReportParserService()
metric_extraction_service = MetricExtractionService()


@router.post("/analyze-health", response_model=AnalyzeHealthResponse)
def analyze_health(payload: AnalyzeHealthRequest) -> AnalyzeHealthResponse:
    return recommendation_service.analyze_health(payload.summary)


@router.post("/parse-medical-report", response_model=ParseMedicalReportResponse)
def parse_medical_report(payload: ParseMedicalReportRequest) -> ParseMedicalReportResponse:
    return report_parser_service.parse(payload.fileName, payload.fileBase64, payload.extractedText)


@router.post("/extract-metrics", response_model=ExtractMetricsResponse)
def extract_metrics(payload: ExtractMetricsRequest) -> ExtractMetricsResponse:
    return metric_extraction_service.extract_metrics(payload.text)
