import base64
import io
from pypdf import PdfReader


def decode_base64_to_text(file_base64: str, filename: str | None = None) -> str:
    raw = base64.b64decode(file_base64)

    if filename and filename.lower().endswith(".pdf"):
        reader = PdfReader(io.BytesIO(raw))
        return "\n".join([page.extract_text() or "" for page in reader.pages]).strip()

    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1", errors="ignore")
