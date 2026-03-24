"""
NIN IFCT 2017 Loader — ingests Indian Food Composition Table data into pgvector RAG.

To load the FULL IFCT 2017 database:
  1. Download from: https://www.nin.res.in/ifct2017.html (free, registration required)
  2. Convert to CSV matching schema in data/ifct2017_sample.csv
  3. Run: python -m app.data.nin_loader --csv-path /path/to/ifct2017_full.csv

The sample CSV (data/ifct2017_sample.csv) contains 20 representative foods and
demonstrates the schema. It is safe to load for development/testing.

Idempotent: uses INSERT ... ON CONFLICT (source, food_code) DO UPDATE so re-runs
update existing rows rather than creating duplicates.
"""
import argparse
import csv
import json
import logging
import os
from pathlib import Path
from typing import Optional

import psycopg2
import psycopg2.extras

logger = logging.getLogger(__name__)

_DEFAULT_CSV = Path(__file__).parent.parent.parent / "data" / "ifct2017_sample.csv"
_EMBED_MODEL = "models/text-embedding-004"
_BATCH_PRINT = 50


def _get_db_conn():
    return psycopg2.connect(
        host     = os.getenv("POSTGRES_HOST", "db"),
        port     = int(os.getenv("POSTGRES_PORT", "5432")),
        dbname   = os.getenv("POSTGRES_DB",   "healthcoach"),
        user     = os.getenv("POSTGRES_USER",  "healthcoach"),
        password = os.getenv("POSTGRES_PASSWORD", ""),
    )


def _build_embedding_text(row: dict) -> str:
    """Build a concise text representation of a food row for embedding."""
    return (
        f"{row['food_name']} ({row['food_group']}): "
        f"{row['energy_kcal']} kcal, "
        f"protein {row['protein_g']}g, "
        f"iron {row['iron_mg']}mg, "
        f"calcium {row['calcium_mg']}mg"
    )


def _build_content_json(row: dict) -> str:
    """Serialise the full nutrient profile as a JSON string for the knowledge_base."""
    return json.dumps({
        "food_code":    row["food_code"],
        "food_name":    row["food_name"],
        "food_group":   row["food_group"],
        "energy_kcal":  _f(row.get("energy_kcal")),
        "protein_g":    _f(row.get("protein_g")),
        "fat_g":        _f(row.get("fat_g")),
        "carb_g":       _f(row.get("carb_g")),
        "fibre_g":      _f(row.get("fibre_g")),
        "calcium_mg":   _f(row.get("calcium_mg")),
        "iron_mg":      _f(row.get("iron_mg")),
        "zinc_mg":      _f(row.get("zinc_mg")),
        "magnesium_mg": _f(row.get("magnesium_mg")),
        "potassium_mg": _f(row.get("potassium_mg")),
        "vitamin_a_mcg":  _f(row.get("vitamin_a_mcg")),
        "vitamin_c_mg":   _f(row.get("vitamin_c_mg")),
        "vitamin_d_mcg":  _f(row.get("vitamin_d_mcg")),
        "vitamin_b12_mcg":_f(row.get("vitamin_b12_mcg")),
        "vitamin_b1_mg":  _f(row.get("vitamin_b1_mg")),
        "vitamin_b2_mg":  _f(row.get("vitamin_b2_mg")),
        "vitamin_b3_mg":  _f(row.get("vitamin_b3_mg")),
        "folate_mcg":     _f(row.get("folate_mcg")),
    }, ensure_ascii=False)


def _f(value) -> Optional[float]:
    """Safe float conversion; returns None for empty/null values."""
    try:
        return float(value) if value not in (None, "", "null") else None
    except (ValueError, TypeError):
        return None


def _get_embeddings(texts: list[str]) -> list[list[float]]:
    """Batch embed texts using Gemini text-embedding-004 via langchain."""
    from langchain_google_genai import GoogleGenerativeAIEmbeddings  # type: ignore
    embedder = GoogleGenerativeAIEmbeddings(
        model=_EMBED_MODEL,
        google_api_key=os.getenv("GEMINI_API_KEY", ""),
    )
    return embedder.embed_documents(texts)


def load_csv(csv_path: Optional[str] = None) -> None:
    """
    Load IFCT food composition CSV into the knowledge_base pgvector table.

    Args:
        csv_path: Path to CSV file. Defaults to data/ifct2017_sample.csv.
    """
    path = Path(csv_path) if csv_path else _DEFAULT_CSV
    if not path.exists():
        raise FileNotFoundError(f"CSV not found: {path}")

    logger.info("Loading IFCT data from %s", path)
    conn = _get_db_conn()
    inserted = 0
    rows_batch: list[dict] = []
    texts_batch: list[str] = []

    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows_batch.append(row)
            texts_batch.append(_build_embedding_text(row))

            if len(rows_batch) >= _BATCH_PRINT:
                _upsert_batch(conn, rows_batch, texts_batch)
                inserted += len(rows_batch)
                print(f"  Loaded {inserted} rows…")
                rows_batch = []
                texts_batch = []

    if rows_batch:
        _upsert_batch(conn, rows_batch, texts_batch)
        inserted += len(rows_batch)

    conn.close()
    print(f"Done. Loaded {inserted} foods into knowledge_base.")


def _upsert_batch(conn, rows: list[dict], texts: list[str]) -> None:
    embeddings = _get_embeddings(texts)

    with conn:
        with conn.cursor() as cur:
            for row, text, embedding in zip(rows, texts, embeddings):
                food_code = row["food_code"]
                content   = _build_content_json(row)
                vec_str   = "[" + ",".join(str(v) for v in embedding) + "]"
                metadata  = json.dumps({
                    "food_code":  food_code,
                    "food_name":  row["food_name"],
                    "food_group": row["food_group"],
                })

                cur.execute(
                    """
                    INSERT INTO knowledge_base
                        (content, embedding, source, category, metadata)
                    VALUES (%s, %s::vector, %s, %s, %s)
                    ON CONFLICT (source, content) DO UPDATE
                        SET embedding = EXCLUDED.embedding,
                            metadata  = EXCLUDED.metadata
                    """,
                    (content, vec_str, "ifct2017", "nutrition", metadata),
                )


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser(
        description="Load IFCT 2017 food composition data into pgvector knowledge_base."
    )
    parser.add_argument(
        "--csv-path",
        default=None,
        help=(
            "Path to IFCT 2017 CSV file. "
            "Download from: https://www.nin.res.in/ifct2017.html "
            "(Defaults to data/ifct2017_sample.csv for testing)"
        ),
    )
    args = parser.parse_args()

    try:
        load_csv(args.csv_path)
    except Exception as exc:
        logger.error("Failed to load IFCT data: %s", exc, exc_info=True)
        sys.exit(1)
