"""
Tests for the multi-model routing layer.

All tests use unittest.mock — no real API calls are made.
Groq and Anthropic SDK stubs are injected into sys.modules at module load time
so tests work even when those packages are not installed (CI / local dev).
"""
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ── SDK stubs (inject before any app imports) ─────────────────────────────────

def _stub_module(name: str) -> types.ModuleType:
    mod = types.ModuleType(name)
    sys.modules[name] = mod
    return mod

if "groq" not in sys.modules:
    _groq_mod = _stub_module("groq")
    _groq_mod.Groq = MagicMock  # type: ignore
    _groq_mod.APIError = Exception  # type: ignore

if "anthropic" not in sys.modules:
    _anth_mod = _stub_module("anthropic")
    _anth_mod.Anthropic = MagicMock  # type: ignore

# ── helpers ───────────────────────────────────────────────────────────────────

def _groq_response(content: str) -> MagicMock:
    msg   = MagicMock(); msg.content = content
    ch    = MagicMock(); ch.message  = msg
    resp  = MagicMock(); resp.choices = [ch]
    return resp

def _claude_response(text: str) -> MagicMock:
    blk  = MagicMock(); blk.text = text
    resp = MagicMock(); resp.content = [blk]
    return resp


# ═══════════════════════════════════════════════════════════════════════════════
# GroqClient tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestGroqClientMissingKey(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()

    def test_raises_value_error_when_key_missing(self):
        with patch.dict("os.environ", {"GROQ_API_KEY": ""}, clear=False):
            from app.ai.groq_client import GroqClient
            with self.assertRaises(ValueError):
                GroqClient()


class TestGroqClientGenerateJson(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()
        # Clear cached module so __init__ picks up fresh mock
        sys.modules.pop("app.ai.groq_client", None)

    def _make_client(self, mock_instance):
        """Create a GroqClient with mock SDK injected."""
        mock_groq_class = MagicMock(return_value=mock_instance)
        sys.modules["groq"].Groq = mock_groq_class  # type: ignore
        with patch.dict("os.environ", {"GROQ_API_KEY": "test-key"}, clear=False):
            from app.ai.groq_client import GroqClient
            return GroqClient()

    def test_returns_parsed_dict(self):
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.return_value = _groq_response('{"result": "ok"}')
        client = self._make_client(mock_sdk)
        result = client.generate_json("sys", "usr")
        self.assertEqual(result, {"result": "ok"})

    def test_strips_markdown_fences(self):
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.return_value = _groq_response(
            "```json\n{\"value\": 42}\n```"
        )
        client = self._make_client(mock_sdk)
        result = client.generate_json("sys", "usr")
        self.assertEqual(result, {"value": 42})

    def test_raises_ai_error_on_invalid_json(self):
        from app.ai.base_client import AIError
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.return_value = _groq_response("not json at all")
        client = self._make_client(mock_sdk)
        with self.assertRaises(AIError):
            client.generate_json("sys", "usr")

    def test_generate_text_returns_string(self):
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.return_value = _groq_response("hello world")
        client = self._make_client(mock_sdk)
        result = client.generate_text("sys", "usr")
        self.assertEqual(result, "hello world")

    def test_vision_json_encodes_image_as_base64(self):
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.return_value = _groq_response('{"foods": []}')
        client = self._make_client(mock_sdk)
        result = client.generate_vision_json("sys", "describe food", b"\xff\xd8\xff", "image/jpeg")
        self.assertEqual(result, {"foods": []})
        # Check that image_url was in the call args
        call_args = mock_sdk.chat.completions.create.call_args
        messages = call_args[1]["messages"] if call_args[1] else call_args[0][0]
        # The user message content should be a list with image_url
        user_msg = next(m for m in messages if m.get("role") == "user")
        content = user_msg["content"]
        self.assertIsInstance(content, list)
        types_seen = {c["type"] for c in content}
        self.assertIn("image_url", types_seen)


class TestGroqClientFallbackOnError(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()
        sys.modules.pop("app.ai.groq_client", None)

    def test_raises_ai_error_after_retries(self):
        from app.ai.base_client import AIError
        mock_sdk = MagicMock()
        mock_sdk.chat.completions.create.side_effect = Exception("timeout")
        mock_groq_class = MagicMock(return_value=mock_sdk)
        sys.modules["groq"].Groq = mock_groq_class  # type: ignore

        with patch.dict("os.environ", {"GROQ_API_KEY": "test-key"}, clear=False):
            from app.ai.groq_client import GroqClient
            client = GroqClient()

        with patch("app.ai.groq_client.time.sleep"):
            with self.assertRaises(AIError):
                client.generate_json("sys", "usr")


# ═══════════════════════════════════════════════════════════════════════════════
# ClaudeClient tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestClaudeClientMissingKey(unittest.TestCase):
    def test_raises_value_error_when_key_missing(self):
        sys.modules.pop("app.ai.claude_client", None)
        with patch.dict("os.environ", {"ANTHROPIC_API_KEY": ""}, clear=False):
            from app.ai.claude_client import ClaudeClient
            with self.assertRaises(ValueError):
                ClaudeClient()


class TestClaudeClientGenerateJson(unittest.TestCase):
    def setUp(self):
        sys.modules.pop("app.ai.claude_client", None)

    def _make_client(self, mock_instance):
        mock_anth_class = MagicMock(return_value=mock_instance)
        sys.modules["anthropic"].Anthropic = mock_anth_class  # type: ignore
        with patch.dict("os.environ", {"ANTHROPIC_API_KEY": "test-key"}, clear=False):
            from app.ai.claude_client import ClaudeClient
            return ClaudeClient()

    def test_returns_parsed_dict(self):
        mock_sdk = MagicMock()
        mock_sdk.messages.create.return_value = _claude_response('{"answer": "yes"}')
        client = self._make_client(mock_sdk)
        result = client.generate_json("sys", "usr")
        self.assertEqual(result, {"answer": "yes"})

    def test_strips_fences(self):
        mock_sdk = MagicMock()
        mock_sdk.messages.create.return_value = _claude_response("```json\n{\"x\": 1}\n```")
        client = self._make_client(mock_sdk)
        result = client.generate_json("sys", "usr")
        self.assertEqual(result, {"x": 1})

    def test_raises_ai_error_on_invalid_json(self):
        from app.ai.base_client import AIError
        mock_sdk = MagicMock()
        mock_sdk.messages.create.return_value = _claude_response("not json")
        client = self._make_client(mock_sdk)
        with self.assertRaises(AIError):
            client.generate_json("sys", "usr")

    def test_generate_text_returns_string(self):
        mock_sdk = MagicMock()
        mock_sdk.messages.create.return_value = _claude_response("plain text response")
        client = self._make_client(mock_sdk)
        result = client.generate_text("sys", "usr")
        self.assertEqual(result, "plain text response")

    def test_retries_on_error(self):
        from app.ai.base_client import AIError
        mock_sdk = MagicMock()
        mock_sdk.messages.create.side_effect = Exception("network error")
        client = self._make_client(mock_sdk)
        with patch("app.ai.claude_client.time.sleep"):
            with self.assertRaises(AIError):
                client.generate_json("sys", "usr")


# ═══════════════════════════════════════════════════════════════════════════════
# model_router tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestModelRouterUsesGroqForFood(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()
        sys.modules.pop("app.ai.groq_client", None)
        sys.modules["groq"].Groq = MagicMock()  # type: ignore

    def test_returns_groq_client_when_key_present(self):
        env = {"GROQ_API_KEY": "test-key", "GEMINI_API_KEY": "test-gemini"}
        with patch.dict("os.environ", env, clear=False):
            with patch("google.generativeai.configure"), \
                 patch("google.generativeai.GenerativeModel"):
                from app.ai.model_router import get_vision_client, _reset_singletons
                _reset_singletons()
                from app.ai.groq_client import GroqClient
                result = get_vision_client("FOOD")
                self.assertIsInstance(result, GroqClient)


class TestModelRouterFallbackToGeminiWhenGroqMissing(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()

    def test_falls_back_to_gemini(self):
        env = {"GROQ_API_KEY": "", "GEMINI_API_KEY": "test-gemini"}
        with patch.dict("os.environ", env, clear=False):
            with patch("google.generativeai.configure"), \
                 patch("google.generativeai.GenerativeModel"):
                from app.ai.model_router import get_vision_client, _reset_singletons
                _reset_singletons()
                from app.ai.gemini_client import GeminiClient
                result = get_vision_client("FOOD")
                self.assertIsInstance(result, GeminiClient)


class TestModelRouterRagAlwaysGemini(unittest.TestCase):
    def setUp(self):
        import app.ai.model_router as mr; mr._reset_singletons()
        sys.modules.pop("app.ai.groq_client", None)
        sys.modules["groq"].Groq = MagicMock()  # type: ignore

    def test_rag_uses_gemini_even_when_groq_available(self):
        env = {"GROQ_API_KEY": "test-key", "GEMINI_API_KEY": "test-gemini"}
        with patch.dict("os.environ", env, clear=False):
            with patch("google.generativeai.configure"), \
                 patch("google.generativeai.GenerativeModel"):
                from app.ai.model_router import get_client, _reset_singletons
                _reset_singletons()
                from app.ai.gemini_client import GeminiClient
                result = get_client("RAG")
                self.assertIsInstance(result, GeminiClient)

    def test_report_always_gemini(self):
        env = {"GROQ_API_KEY": "test-key", "GEMINI_API_KEY": "test-gemini"}
        with patch.dict("os.environ", env, clear=False):
            with patch("google.generativeai.configure"), \
                 patch("google.generativeai.GenerativeModel"):
                from app.ai.model_router import get_client, _reset_singletons
                _reset_singletons()
                from app.ai.gemini_client import GeminiClient
                result = get_client("REPORT")
                self.assertIsInstance(result, GeminiClient)

    def test_text_uses_groq_when_available(self):
        env = {"GROQ_API_KEY": "test-key", "GEMINI_API_KEY": "test-gemini"}
        with patch.dict("os.environ", env, clear=False):
            with patch("google.generativeai.configure"), \
                 patch("google.generativeai.GenerativeModel"):
                from app.ai.model_router import get_client, _reset_singletons
                _reset_singletons()
                from app.ai.groq_client import GroqClient
                result = get_client("TEXT")
                self.assertIsInstance(result, GroqClient)

    def test_reset_singletons_clears_state(self):
        from app.ai.model_router import _reset_singletons
        import app.ai.model_router as mr
        # Set some state
        mr._groq_init_failed = True
        _reset_singletons()
        self.assertFalse(mr._groq_init_failed)
        self.assertIsNone(mr._groq_client)
        self.assertIsNone(mr._gemini_client)


# ═══════════════════════════════════════════════════════════════════════════════
# PaddleOCR tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestPaddleOCRReturnsNoneWhenNotInstalled(unittest.TestCase):
    def test_returns_none_on_import_error(self):
        sys.modules.pop("app.ai.paddleocr_client", None)
        sys.modules["paddleocr"] = None  # type: ignore  # simulate missing module

        try:
            from app.ai.paddleocr_client import PaddleOCRClient
            client = PaddleOCRClient()
            result = client.extract_text(b"some pdf bytes", "application/pdf")
            self.assertIsNone(result)
        finally:
            sys.modules.pop("paddleocr", None)
            sys.modules.pop("app.ai.paddleocr_client", None)

    def test_extract_text_empty_bytes_returns_none(self):
        sys.modules.pop("app.ai.paddleocr_client", None)
        sys.modules.pop("paddleocr", None)

        from app.ai.paddleocr_client import PaddleOCRClient
        client = PaddleOCRClient()
        # OCR unavailable (no paddleocr installed) — pypdf will fail on empty bytes
        result = client.extract_text(b"", "application/pdf")
        self.assertIsNone(result)


class TestPaddleOCRPyPdfPath(unittest.TestCase):
    """Test the pypdf fast-path."""

    def test_pypdf_used_when_text_sufficient(self):
        sys.modules.pop("app.ai.paddleocr_client", None)
        sys.modules.pop("paddleocr", None)

        from app.ai.paddleocr_client import PaddleOCRClient
        client = PaddleOCRClient()

        long_text = "Patient Name: John Doe\n" * 5  # well over 50 chars
        mock_page = MagicMock()
        mock_page.extract_text.return_value = long_text
        mock_reader = MagicMock()
        mock_reader.pages = [mock_page]

        with patch("pypdf.PdfReader", return_value=mock_reader):
            result = client.extract_text(b"%PDF dummy", "application/pdf")
        self.assertIsNotNone(result)
        self.assertIn("Patient Name", result)


# ═══════════════════════════════════════════════════════════════════════════════
# ICMR RDA tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestICMRRda(unittest.TestCase):
    def test_women_have_higher_iron_rda(self):
        from app.data.icmr_rda import get_rda
        self.assertGreater(get_rda("female", 25)["iron_mg"], get_rda("male", 25)["iron_mg"])

    def test_women_adult_iron_is_29(self):
        from app.data.icmr_rda import get_rda
        self.assertEqual(get_rda("female", 25)["iron_mg"], 29.0)

    def test_men_adult_iron_is_17(self):
        from app.data.icmr_rda import get_rda
        self.assertEqual(get_rda("male", 30)["iron_mg"], 17.0)

    def test_child_age_group(self):
        from app.data.icmr_rda import get_rda
        rda = get_rda("male", 2)
        self.assertIn("iron_mg", rda)

    def test_elderly_higher_vitamin_d(self):
        from app.data.icmr_rda import get_rda
        elderly = get_rda("male", 60)
        adult   = get_rda("male", 30)
        self.assertGreaterEqual(elderly["vitamin_d_mcg"], adult["vitamin_d_mcg"])

    def test_pregnant_high_folate(self):
        from app.data.icmr_rda import ICMR_RDA
        pregnant = ICMR_RDA[("female", "pregnant")]
        adult    = ICMR_RDA[("female", "adult")]
        self.assertGreater(pregnant["vitamin_b9_mcg"], adult["vitamin_b9_mcg"])

    def test_unknown_gender_defaults_to_male(self):
        from app.data.icmr_rda import get_rda
        rda_unknown = get_rda("nonbinary", 30)
        rda_male    = get_rda("male",      30)
        self.assertEqual(rda_unknown["iron_mg"], rda_male["iron_mg"])

    def test_none_age_defaults_to_adult(self):
        from app.data.icmr_rda import get_rda
        rda_none  = get_rda("male", None)
        rda_adult = get_rda("male", 30)
        self.assertEqual(rda_none["iron_mg"], rda_adult["iron_mg"])

    def test_rda_percentage_calculation(self):
        from app.data.icmr_rda import get_rda_percentage
        pct = get_rda_percentage("iron_mg", 17.0, "male", 30)
        self.assertAlmostEqual(pct, 100.0, places=1)

    def test_rda_percentage_capped_at_200(self):
        from app.data.icmr_rda import get_rda_percentage
        pct = get_rda_percentage("iron_mg", 10_000.0, "male", 30)
        self.assertEqual(pct, 200.0)

    def test_rda_percentage_unknown_nutrient_returns_zero(self):
        from app.data.icmr_rda import get_rda_percentage
        pct = get_rda_percentage("omega3_g", 5.0, "male", 30)
        self.assertEqual(pct, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# Portion sizes tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestPortionSizes(unittest.TestCase):
    def test_two_katoris(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("2 katoris"), 300.0)

    def test_one_katori(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("1 katori"), 150.0)

    def test_three_rotis(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("3 rotis"), 90.0)

    def test_one_tbsp(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("1 tbsp"), 15.0)

    def test_half_cup(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("0.5 cup"), 120.0)

    def test_two_idlis(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("2 idli"), 80.0)

    def test_paratha(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("1 paratha"), 60.0)

    def test_unknown_unit_returns_none(self):
        from app.data.portion_sizes import resolve_portion
        self.assertIsNone(resolve_portion("1 mug"))

    def test_empty_string_returns_none(self):
        from app.data.portion_sizes import resolve_portion
        self.assertIsNone(resolve_portion(""))

    def test_none_handled(self):
        from app.data.portion_sizes import resolve_portion
        self.assertIsNone(resolve_portion(None))  # type: ignore

    def test_tablespoon_alias(self):
        from app.data.portion_sizes import resolve_portion
        self.assertEqual(resolve_portion("2 tablespoon"), 30.0)


if __name__ == "__main__":
    unittest.main()
