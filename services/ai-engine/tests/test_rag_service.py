"""
Tests for rag_service — mocks out Gemini and psycopg2 so the suite runs offline.
"""
from unittest.mock import MagicMock, patch

import app.services.rag_service as rag


# ── Unit tests for internal helpers ───────────────────────────────────────────

class TestEmbedQuery:
    def test_returns_list_on_success(self):
        fake_embedding = [0.1] * 768
        with patch.object(rag.genai, "embed_content", return_value={"embedding": fake_embedding}):
            result = rag._embed_query("How much protein do I need?")
        assert result == fake_embedding

    def test_returns_none_on_exception(self):
        with patch.object(rag.genai, "embed_content", side_effect=Exception("API error")):
            result = rag._embed_query("some query")
        assert result is None


class TestRetrieveChunks:
    def _make_mock_conn(self, rows):
        mock_cur = MagicMock()
        mock_cur.__enter__ = lambda s: s
        mock_cur.__exit__ = MagicMock(return_value=False)
        mock_cur.fetchall.return_value = [dict(r) for r in rows]

        mock_conn = MagicMock()
        mock_conn.__enter__ = lambda s: s
        mock_conn.__exit__ = MagicMock(return_value=False)
        mock_conn.cursor.return_value = mock_cur
        return mock_conn

    def test_returns_empty_when_db_unavailable(self):
        with patch.object(rag, "_get_db_conn", return_value=None):
            result = rag._retrieve_chunks([0.1] * 768)
        assert result == []

    def test_returns_chunks_from_db(self):
        rows = [
            {"content": "Iron is important", "source": "ICMR_2024", "category": "iron_deficiency", "similarity": 0.9},
        ]
        mock_conn = self._make_mock_conn(rows)
        with patch.object(rag, "_get_db_conn", return_value=mock_conn):
            result = rag._retrieve_chunks([0.1] * 768)
        assert len(result) == 1
        assert result[0]["content"] == "Iron is important"

    def test_category_filter_applied(self):
        rows: list = []
        mock_conn = self._make_mock_conn(rows)
        with patch.object(rag, "_get_db_conn", return_value=mock_conn):
            result = rag._retrieve_chunks([0.1] * 768, category="iron_deficiency")
        assert result == []

    def test_returns_empty_on_db_exception(self):
        mock_conn = MagicMock()
        mock_conn.__enter__ = lambda s: s
        mock_conn.__exit__ = MagicMock(return_value=False)
        mock_conn.cursor.side_effect = Exception("DB error")
        with patch.object(rag, "_get_db_conn", return_value=mock_conn):
            result = rag._retrieve_chunks([0.1] * 768)
        assert result == []


class TestSynthesise:
    def test_returns_synthesised_text(self):
        mock_resp = MagicMock()
        mock_resp.text = "  Eat more dal for protein.  "
        with patch.object(rag.genai, "GenerativeModel") as mock_model_cls:
            mock_model_cls.return_value.generate_content.return_value = mock_resp
            result = rag._synthesise(
                "How much protein?",
                [{"content": "Protein RDA is 0.8g/kg", "source": "ICMR", "category": "protein"}],
                {"region": "India"},
            )
        assert result == "Eat more dal for protein."

    def test_handles_empty_chunks(self):
        mock_resp = MagicMock()
        mock_resp.text = "General advice."
        with patch.object(rag.genai, "GenerativeModel") as mock_model_cls:
            mock_model_cls.return_value.generate_content.return_value = mock_resp
            result = rag._synthesise("What to eat?", [], {})
        assert "General advice." in result

    def test_returns_fallback_on_gemini_error(self):
        with patch.object(rag.genai, "GenerativeModel") as mock_model_cls:
            mock_model_cls.return_value.generate_content.side_effect = Exception("timeout")
            result = rag._synthesise("query", [], {})
        assert "trouble" in result.lower() or "try again" in result.lower()


class TestAnswerQuery:
    def test_full_pipeline_returns_expected_keys(self):
        fake_embedding = [0.1] * 768
        fake_chunks = [
            {"content": "Iron deficiency is common.", "source": "ICMR", "category": "iron_deficiency", "similarity": 0.85}
        ]
        with (
            patch.object(rag, "_embed_query", return_value=fake_embedding),
            patch.object(rag, "_retrieve_chunks", return_value=fake_chunks),
            patch.object(rag, "_synthesise", return_value="Eat more spinach."),
        ):
            result = rag.answer_query("I feel tired all the time", {"region": "India"})

        assert result["answer"] == "Eat more spinach."
        assert result["chunks_used"] == 1
        assert "sources" in result

    def test_fallback_when_embedding_fails(self):
        with (
            patch.object(rag, "_embed_query", return_value=None),
            patch.object(rag, "_synthesise", return_value="General advice."),
        ):
            result = rag.answer_query("general question", {})

        assert result["chunks_used"] == 0
        assert result["answer"] == "General advice."

    def test_sources_deduplicated(self):
        fake_embedding = [0.0] * 768
        fake_chunks = [
            {"content": "chunk1", "source": "ICMR", "category": "protein"},
            {"content": "chunk2", "source": "ICMR", "category": "protein"},
            {"content": "chunk3", "source": "FSSAI", "category": "gut_health"},
        ]
        with (
            patch.object(rag, "_embed_query", return_value=fake_embedding),
            patch.object(rag, "_retrieve_chunks", return_value=fake_chunks),
            patch.object(rag, "_synthesise", return_value="Answer."),
        ):
            result = rag.answer_query("question", {})

        assert len(result["sources"]) == 2
        assert set(result["sources"]) == {"ICMR", "FSSAI"}
