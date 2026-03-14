"""
GCS download helper — fetches file bytes from a gs:// URI.

Used by the AI Engine when the Spring Boot Orchestrator has uploaded
a food image or medical PDF to GCS (claim-check pattern) and passed
the URI in the RabbitMQ payload instead of base64 bytes.

Graceful fallback: if google-cloud-storage is not installed or GCS
credentials are absent, returns None and the caller falls back to
whatever base64 bytes were provided inline.
"""
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


def download_gcs_bytes(uri: str) -> Optional[bytes]:
    """
    Download a GCS object and return its raw bytes.

    :param uri: gs://bucket/path/to/object
    :returns:   raw bytes, or None on error / if library unavailable
    """
    if not uri or not uri.startswith("gs://"):
        return None

    try:
        from google.cloud import storage  # type: ignore
        # Strip gs:// prefix → "bucket/path/to/object"
        path = uri[len("gs://"):]
        bucket_name, _, object_name = path.partition("/")
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(object_name)
        data = blob.download_as_bytes()
        logger.debug("Downloaded %d bytes from %s", len(data), uri)
        return data
    except ImportError:
        logger.warning("google-cloud-storage not installed — cannot download from GCS")
        return None
    except Exception as e:
        logger.warning("GCS download failed for %s: %s", uri, e)
        return None


def resolve_payload(url_or_b64: str | None) -> tuple[bytes | None, str]:
    """
    Resolve an imageUrl / documentUrl field from a RabbitMQ payload.

    If the value is a gs:// URI → download from GCS → return (bytes, "gcs").
    Otherwise treat as base64 → return (None, "base64") so the caller
    decodes it the usual way.

    Returns (bytes_or_none, source_type)
    """
    if not url_or_b64:
        return None, "empty"
    if url_or_b64.startswith("gs://"):
        data = download_gcs_bytes(url_or_b64)
        return data, "gcs"
    return None, "base64"
