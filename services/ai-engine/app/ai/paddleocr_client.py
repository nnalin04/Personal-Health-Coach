"""
PaddleOCR local pre-processor — runs entirely on CPU, no API key required.

Purpose: extract text from medical PDFs/images BEFORE any LLM call,
cutting LLM token cost ~80% by replacing vision inference with a
cheap text-only call.

Logic:
  PDF  → try pypdf first (embedded text, free) → if >= 50 chars, done
       → otherwise fall through to PaddleOCR
  Image → encode to numpy array → run PaddleOCR

If paddleocr is not installed (ImportError), logs a warning and returns None.
Caller falls through to the vision LLM path. Never raises — always degrades
gracefully so the service continues even without OCR support.
"""
import io
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)


class PaddleOCRClient:
    """Local OCR pre-processor using PaddleOCR."""

    def __init__(self) -> None:
        self._ocr = None
        try:
            from paddleocr import PaddleOCR  # type: ignore
            self._ocr = PaddleOCR(use_angle_cls=True, lang="en", show_log=False)
            logger.info("PaddleOCRClient initialised (lang=en)")
        except ImportError:
            logger.warning(
                "paddleocr not installed — OCR pre-pass disabled. "
                "Install with: pip install paddleocr paddlepaddle"
            )
        except Exception as exc:
            logger.warning("PaddleOCR init failed (%s) — OCR pre-pass disabled", exc)

    def extract_text(
        self,
        file_data: bytes,
        mime_type: str = "application/pdf",
    ) -> Optional[str]:
        """
        Extract text from PDF or image bytes.

        Returns extracted text string, or None if extraction failed or
        PaddleOCR is unavailable (caller should fall through to vision LLM).
        """
        try:
            if mime_type == "application/pdf" or mime_type.endswith("/pdf"):
                result = self._try_pypdf(file_data)
                if result is not None:
                    return result
                # pypdf found < 50 chars — fall through to OCR

            return self._run_paddle_ocr(file_data, mime_type)

        except Exception as exc:
            logger.warning("PaddleOCR extract_text error (%s) — returning None", exc)
            return None

    # ── private ───────────────────────────────────────────────────────────────

    def _try_pypdf(self, pdf_bytes: bytes) -> Optional[str]:
        """Attempt text extraction via pypdf. Returns text if >= 50 chars, else None."""
        try:
            import pypdf  # already in requirements.txt

            reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
            pages_text = []
            for page in reader.pages:
                text = page.extract_text()
                if text:
                    pages_text.append(text.strip())
            full_text = "\n".join(pages_text).strip()
            if len(full_text) >= 50:
                logger.debug("pypdf extracted %d chars — skipping OCR", len(full_text))
                return full_text
            logger.debug(
                "pypdf extracted only %d chars — falling through to PaddleOCR",
                len(full_text),
            )
            return None
        except Exception as exc:
            logger.debug("pypdf extraction failed (%s) — falling through to PaddleOCR", exc)
            return None

    def _run_paddle_ocr(self, file_data: bytes, mime_type: str) -> Optional[str]:
        """Run PaddleOCR on image bytes. Returns joined text or None."""
        if self._ocr is None:
            return None
        try:
            import PIL.Image  # type: ignore

            img = PIL.Image.open(io.BytesIO(file_data)).convert("RGB")
            img_array = np.array(img)
            result = self._ocr.ocr(img_array, cls=True)
            if not result:
                return None
            lines = []
            for page_result in result:
                if page_result:
                    for line in page_result:
                        if line and len(line) >= 2:
                            text_info = line[1]
                            if text_info and text_info[0]:
                                lines.append(text_info[0])
            extracted = "\n".join(lines).strip()
            if extracted:
                logger.debug("PaddleOCR extracted %d chars", len(extracted))
                return extracted
            return None
        except Exception as exc:
            logger.warning("PaddleOCR inference failed (%s)", exc)
            return None
