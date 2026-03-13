import json
import os
import google.generativeai as genai

class GeminiClient:
    def __init__(self) -> None:
        api_key = os.getenv("GEMINI_API_KEY", "").strip()
        if not api_key:
            raise ValueError(
                "GEMINI_API_KEY environment variable is not set or is empty. "
                "The AI service cannot start without a valid Gemini API key."
            )
        self.model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-pro")
        self.enabled = True
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel(self.model_name)

    def generate_json(self, system_prompt: str, user_prompt: str, contents: list | None = None) -> dict:
        if not self.enabled or self.model is None:
            raise RuntimeError("Gemini API key not configured")

        if contents is None:
            contents = [f"{system_prompt}\n\n{user_prompt}"]
        else:
            # Add system prompt as instructions
            contents.insert(0, system_prompt)
            contents.append(user_prompt)
        
        response = self.model.generate_content(
            contents,
            generation_config=genai.types.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.2,
            )
        )
        
        content = response.text or "{}"
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            # Cleanup potential markdown wrapping
            clean_content = content.replace("```json", "").replace("```", "").strip()
            return json.loads(clean_content)
