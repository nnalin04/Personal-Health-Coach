from pydantic import BaseModel, Field


class ParseMedicalReportRequest(BaseModel):
    fileName: str | None = None
    fileBase64: str | None = None
    extractedText: str | None = None


class ParsedLabValues(BaseModel):
    vitamin_d: float | None = None
    tsh: float | None = None
    ldl: float | None = None
    hdl: float | None = None
    triglycerides: float | None = None
    hba1c: float | None = None
    creatinine: float | None = None
    hemoglobin: float | None = None
    alt: float | None = None
    ast: float | None = None
    glucose: float | None = None
    testosterone: float | None = None


class ParseMedicalReportResponse(BaseModel):
    labValues: ParsedLabValues
    extractionNotes: list[str] = Field(default_factory=list)
