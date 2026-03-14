"""
Profile Update Router — synchronous endpoint called by Spring Boot Orchestrator
when a TEXT Omni-Chat message may contain profile update intent.

POST /api/v1/chat/parse-profile-update
  Request:  { "message": str }
  Response: {
    "isProfileUpdate": bool,
    "fields": {                      # only present when isProfileUpdate=true
      "weightKg":            number,
      "heightCm":            number,
      "region":              string,
      "healthGoal":          string,
      "gender":              string,
      "cuisineStyle":        string,
      "dietaryRestrictions": string,
      "age":                 integer
    },
    "confirmationMessage": string    # only present when isProfileUpdate=true
  }
"""
from fastapi import APIRouter
from pydantic import BaseModel
from app.services.profile_update_service import ProfileUpdateService

router = APIRouter(prefix="/api/v1/chat", tags=["omni-chat"])

_service = ProfileUpdateService()


class ParseProfileUpdateRequest(BaseModel):
    message: str


@router.post("/parse-profile-update")
def parse_profile_update(request: ParseProfileUpdateRequest) -> dict:
    """
    Classify and parse a natural-language profile update intent.
    Called synchronously by OmniChatController before deciding whether to
    publish an async RAG task or execute an immediate profile update.
    """
    return _service.parse(request.message)
