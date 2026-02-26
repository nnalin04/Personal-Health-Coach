import json
from app.ai.gemini_client import GeminiClient
from app.schemas.health import AnalyzeHealthResponse


class RecommendationService:
    def __init__(self) -> None:
        self.gemini_client = GeminiClient()

    def analyze_health(self, summary: dict) -> AnalyzeHealthResponse:
        try:
            return self._gemini_analysis(summary)
        except Exception:
            return self._fallback_analysis(summary)

    def _gemini_analysis(self, summary: dict) -> AnalyzeHealthResponse:
        goal = summary.get("profile", {}).get("goal", "general health")
        risk_flags = summary.get("risk_flags", [])
        
        # Simple knowledge retrieval based on risk/goals
        retrieved_context = self._retrieve_knowledge(goal, risk_flags)

        system_prompt = (
            "You are a high-performance health coach. "
            "Use the provided scientific context and user summary to generate actionable, non-diagnostic guidance. "
            "Return strict JSON."
        )
        user_prompt = (
            f"User Goal: {goal}\n"
            f"Scientific Context: {retrieved_context}\n"
            "Health Summary JSON: " + json.dumps(summary) + "\n\n"
            "Generate concise guidance with keys: dietSuggestions, trainingSuggestions, recoverySuggestions, medicalAwarenessNotes, disclaimer."
        )
        output = self.gemini_client.generate_json(system_prompt, user_prompt)
        return AnalyzeHealthResponse(
            dietSuggestions=output.get("dietSuggestions", []),
            trainingSuggestions=output.get("trainingSuggestions", []),
            recoverySuggestions=output.get("recoverySuggestions", []),
            medicalAwarenessNotes=output.get("medicalAwarenessNotes", []),
            disclaimer=output.get(
                "disclaimer",
                "This is educational guidance only and not a medical diagnosis.",
            ),
        )

    def _retrieve_knowledge(self, goal: str, risk_flags: list[str]) -> str:
        # Placeholder for RAG retrieval logic
        # In a real system, this would query a Vector DB (Chroma/FAISS)
        context = []
        if "weight" in goal.lower():
            context.append("Focus on high-satiety foods, protein-sparing modified fast principles, and caloric deficit management.")
        if any("protein deficit" in f.lower() for f in risk_flags):
            context.append("Leucine-rich protein sources (whey, beef, soy) are critical for muscle protein synthesis during deficits.")
        if any("medical lab deterioration" in f.lower() for f in risk_flags):
            context.append("Metabolic markers (LDL, HbA1c) are highly responsive to fiber intake and Zone 2 cardiovascular training.")
        
        return " ".join(context) if context else "Standard health and wellness principles apply."

    def _fallback_analysis(self, summary: dict) -> AnalyzeHealthResponse:
        risk_flags: list[str] = summary.get("risk_flags", [])
        nutrition = summary.get("nutrition_summary", {})
        training = summary.get("training_summary", {})

        diet = [
            "Prioritize whole-food protein in each meal and distribute intake evenly.",
            "Aim for fiber-rich vegetables and hydration consistency daily.",
        ]
        if any("protein deficit" in flag.lower() for flag in risk_flags):
            diet.insert(0, "Recent trend suggests low protein intake. Increase lean protein servings.")

        training_suggestions = [
            "Keep 3-4 resistance sessions weekly with progressive overload tracking.",
            "Include at least 2 low-intensity cardio sessions for recovery and consistency.",
        ]
        workout_freq = training.get("workout_frequency", {}).get("last_30_days", 0)
        if isinstance(workout_freq, (int, float)) and workout_freq < 2.0:
            training_suggestions.insert(0, "Training frequency appears low. Start with a sustainable 3-day split.")

        recovery = [
            "Target 7-9 hours sleep and keep wake/sleep timing consistent.",
            "Add one lighter day weekly to manage fatigue.",
        ]

        medical_notes = [
            "Track lab trends over time and discuss persistent adverse changes with your clinician.",
            "Do not use these insights as a diagnosis or replacement for medical advice.",
        ]

        avg_calories = nutrition.get("last_7_days", {}).get("avg_calories")
        if isinstance(avg_calories, (int, float)) and avg_calories < 1200:
            medical_notes.insert(0, "Recent calorie intake appears low; ensure adequacy for recovery and energy.")

        return AnalyzeHealthResponse(
            dietSuggestions=diet,
            trainingSuggestions=training_suggestions,
            recoverySuggestions=recovery,
            medicalAwarenessNotes=medical_notes,
            disclaimer="This is educational guidance only and not a medical diagnosis.",
        )
