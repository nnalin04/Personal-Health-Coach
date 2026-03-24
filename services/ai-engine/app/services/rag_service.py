"""
RAG (Retrieval-Augmented Generation) service.

Embeds the user query with Gemini text-embedding-004, performs cosine
similarity search against the knowledge_base table (pgvector HNSW index),
then feeds the top-k chunks + user context to Gemini for answer synthesis.

Falls back gracefully to a direct Gemini call (no retrieval) if the
knowledge_base is empty or the DB is unavailable.
"""
import logging
import os
from typing import Optional

import google.generativeai as genai
import psycopg2
import psycopg2.extras

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL   = os.getenv("GEMINI_MODEL", "gemini-2.5-pro")
EMBED_MODEL    = "models/text-embedding-004"
TOP_K          = 5       # chunks to retrieve
EMBED_DIM      = 768     # text-embedding-004 output dimension


def _configure_genai():
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)


def _get_db_conn() -> Optional[psycopg2.extensions.connection]:
    try:
        return psycopg2.connect(
            host     = os.getenv("POSTGRES_HOST", "db"),
            port     = int(os.getenv("POSTGRES_PORT", "5432")),
            dbname   = os.getenv("POSTGRES_DB",   "healthcoach"),
            user     = os.getenv("POSTGRES_USER",  "healthcoach"),
            password = os.getenv("POSTGRES_PASSWORD", ""),
        )
    except Exception as e:
        logger.warning("RAG: DB unavailable: %s", e)
        return None


def _embed_query(query: str) -> Optional[list[float]]:
    """Return a 768-dim embedding for the query text, or None on failure."""
    try:
        _configure_genai()
        result = genai.embed_content(
            model   = EMBED_MODEL,
            content = query,
            task_type = "RETRIEVAL_QUERY",
        )
        return result["embedding"]
    except Exception as e:
        logger.warning("RAG: embedding failed: %s", e)
        return None


def _retrieve_chunks(query_embedding: list[float], category: Optional[str] = None) -> list[dict]:
    """Cosine similarity search in knowledge_base. Returns top-K chunks."""
    conn = _get_db_conn()
    if conn is None:
        return []
    try:
        vec_str = "[" + ",".join(str(v) for v in query_embedding) + "]"
        with conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                if category:
                    cur.execute(
                        """SELECT content, source, category,
                                  1 - (embedding <=> %s::vector) AS similarity
                           FROM knowledge_base
                           WHERE category = %s AND embedding IS NOT NULL
                           ORDER BY embedding <=> %s::vector
                           LIMIT %s""",
                        (vec_str, category, vec_str, TOP_K),
                    )
                else:
                    cur.execute(
                        """SELECT content, source, category,
                                  1 - (embedding <=> %s::vector) AS similarity
                           FROM knowledge_base
                           WHERE embedding IS NOT NULL
                           ORDER BY embedding <=> %s::vector
                           LIMIT %s""",
                        (vec_str, vec_str, TOP_K),
                    )
                return [dict(r) for r in cur.fetchall()]
    except Exception as e:
        logger.warning("RAG: retrieval failed: %s", e)
        return []
    finally:
        conn.close()


def _synthesise(query: str, chunks: list[dict], user_context: dict) -> str:
    """Feed retrieved chunks + user context to Gemini for a grounded answer."""
    _configure_genai()

    if chunks:
        context_block = "\n\n".join(
            f"[Source: {c.get('source','?')} | Category: {c.get('category','?')}]\n{c['content']}"
            for c in chunks
        )
    else:
        context_block = "(No relevant knowledge base entries found — answer from general knowledge)"

    region    = user_context.get("region", "India")
    cuisine   = user_context.get("cuisineStyle", "mixed")
    diet      = user_context.get("dietaryRestrictions", "none")
    goal      = user_context.get("healthGoal", "general wellness")
    spice     = user_context.get("spicePreference", "medium")
    grains    = user_context.get("stapleGrains", "rice/wheat")

    prompt = f"""You are an expert AI health coach specialised in Indian nutrition and wellness.

User profile:
- Region: {region}
- Cuisine style: {cuisine}
- Dietary restrictions: {diet}
- Health goal: {goal}
- Spice preference: {spice}
- Staple grains: {grains}

Reference knowledge (from ICMR/FSSAI guidelines and validated health literature):
{context_block}

User question: {query}

Instructions:
- Answer concisely (3-5 sentences) using the reference knowledge above when relevant.
- Make recommendations culturally appropriate for the user's region and cuisine style.
- If suggesting foods, prefer regionally available options.
- If the question is unrelated to health/nutrition, politely redirect.
- Do NOT hallucinate sources. Only cite sources listed above.
"""
    try:
        model = genai.GenerativeModel(GEMINI_MODEL)
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        logger.error("RAG: Gemini synthesis failed: %s", e)
        return "I'm having trouble generating a response right now. Please try again."


def answer_query(query: str, user_context: dict, category: Optional[str] = None,
                 client=None) -> dict:
    """
    Full RAG pipeline: embed → retrieve → synthesise.

    Returns:
        { "answer": str, "sources": list[str], "chunks_used": int }
    """
    embedding = _embed_query(query)
    chunks = _retrieve_chunks(embedding, category) if embedding else []

    answer = _synthesise(query, chunks, user_context)
    sources = list({c.get("source", "?") for c in chunks if c.get("source")})

    return {
        "answer":      answer,
        "sources":     sources,
        "chunks_used": len(chunks),
    }
