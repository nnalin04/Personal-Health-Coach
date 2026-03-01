# Nutrient Intelligence Feature — Implementation Plan

## Overview

Enable users to photograph or describe their meals and receive:
- Micronutrient breakdown (vitamins + minerals)
- Daily deficiency tracking vs RDA
- Culturally-aware food and supplement recommendations

---

## Core Principle: Smart LLM Usage

Do **one** Gemini call per user action, returning a structured JSON payload.
Never chain multiple Gemini calls for a single food event.
Use the existing `generate_json()` pattern with `response_mime_type="application/json"`.

---

## Feature Breakdown

### 1. Food Analysis (Image + Text → Nutrients)

**Trigger:** User taps "Log Food" and either:
- Takes/selects a photo of their meal
- Types what they are eating in free text

**Flow:**
```
Mobile → POST /food/analyze-nutrients
  body: { image_base64?: str, description?: str, user_context: UserNutrientContext }

AI Service → Single Gemini call with vision if image provided
  returns: { foods: [...], nutrients: NutrientProfile, confidence: float }

Backend → Stores NutrientLog linked to FoodEntry
Mobile → Shows nutrient breakdown + any deficiency alerts
```

**Gemini prompt design:**
```
System: You are a nutrition expert AI. Return only valid JSON.
User: Analyze this meal [image/description].
      User is from [region], prefers [cuisine type].
      Return: {
        "foods": [{"name": str, "portion_g": int, "confidence": float}],
        "nutrients": {
          "vitamins": {"a_mcg": float, "b1_mg": float, "b2_mg": float, "b3_mg": float,
                       "b6_mg": float, "b9_mcg": float, "b12_mcg": float,
                       "c_mg": float, "d_mcg": float, "e_mg": float, "k_mcg": float},
          "minerals": {"calcium_mg": float, "iron_mg": float, "zinc_mg": float,
                       "magnesium_mg": float, "potassium_mg": float,
                       "selenium_mcg": float, "iodine_mcg": float}
        },
        "total_calories": int,
        "confidence_note": str
      }
```

---

### 2. Daily Deficiency Tracking

**Backend Entity: `NutrientLog`**
```
user_id | date | meal_type | vitamin_a | vitamin_c | iron | calcium | ... | food_entry_id
```

**Daily Aggregation:**
- Sum all `NutrientLog` entries for a user for today
- Compare vs RDA per nutrient (stored as constants)
- Generate `NutrientDeficiencySummary`: which nutrients are below 80% RDA

**Backend Endpoint:**
```
GET /nutrient/daily-summary          → today's intake vs RDA
GET /nutrient/weekly-trends          → 7-day micronutrient history
GET /nutrient/deficiency-profile     → recurring deficiencies (last 14 days)
```

**RDA Reference Values (stored as constants in backend):**
```
Vitamin A: 900mcg (M) / 700mcg (F)
Vitamin C: 90mg (M) / 75mg (F)
Vitamin D: 15mcg
Iron: 8mg (M) / 18mg (F)
Calcium: 1000mg
Zinc: 11mg (M) / 8mg (F)
Magnesium: 420mg (M) / 320mg (F)
B12: 2.4mcg
... etc
```

---

### 3. Culturally-Aware Recommendations

**Trigger:** AI Insights call OR after 3+ days of deficiency data

**User Profile Extension:**
```
user_preferences: {
  region: "Bihar, India",       // set during onboarding or inferred from timezone
  cuisine_style: "north_indian",  // inferred from food logs
  dietary_restrictions: ["vegetarian"],  // user-set
  disliked_foods: []             // learned from ratings
}
```

**Gemini Recommendation Call:**
```
System: You are a culturally-sensitive nutrition expert.
        Only suggest foods available in and commonly eaten in [region].
        Never suggest foods outside the user's dietary restrictions.
User:   User has these deficiencies over the past 14 days: [deficiency list]
        Their typical meals: [last 7 days food summary - compressed]
        Region: [region], Cuisine preference: [cuisine]
        Return JSON: {
          "deficiency_insights": [
            {
              "nutrient": "Iron",
              "level": "below 60% RDA for 10/14 days",
              "impact": "fatigue, reduced immunity"
            }
          ],
          "food_recommendations": [
            {
              "for_deficiency": "Iron",
              "food": "Palak Dal (spinach lentil curry)",
              "reason": "Iron-rich spinach + vitamin C from tomatoes improves absorption. Pairs with your existing dal-rice meals.",
              "how_to_add": "Replace plain dal with palak dal 3x/week"
            }
          ],
          "supplement_suggestions": [
            {
              "for_deficiency": "Vitamin D",
              "supplement": "Vitamin D3 1000IU",
              "reason": "Minimal sun exposure + vegetarian diet limits dietary sources",
              "food_alternative": "Fortified milk (dudh) or mushrooms exposed to sunlight"
            }
          ]
        }
```

**Key Design Principles:**
- If user loves dal-rice → suggest `palak dal`, `methi dal`, `rajma`, not quinoa or tofu
- If user is vegetarian → never suggest meat; suggest dairy, legumes, seeds
- Recommendations should feel like advice from a knowledgeable neighbour, not a generic app
- When food swaps can solve the deficiency → prefer food over supplements
- When supplement is truly needed → name a commonly available one with food alternative fallback

---

### 4. Mobile UX

**Food Log Screen Enhancement:**
```
[📷 Photo]  [✏️ Describe]  [Search]   ← existing + new buttons

After log:
┌─────────────────────────────────────┐
│ Nutrient Breakdown                  │
│ Protein ████████░░ 24g              │
│ Iron    ███░░░░░░░ 3.2mg / 8mg RDA  │
│ Vit C   ██████████ 72mg ✓           │
│ ⚠ Low iron detected for 5 days      │
│ → Tap to see food suggestions       │
└─────────────────────────────────────┘
```

**Nutrient Dashboard Screen (new):**
- Weekly micronutrient heatmap
- Deficiency alerts with "fix it" suggestions
- Progress over time (as user follows recommendations)

**Insights Screen Enhancement:**
- Add "Nutrition Intelligence" section to AI insights
- Shows: top 3 deficiencies + top 3 culturally-relevant food suggestions
- Refreshes weekly from new Gemini analysis

---

## Implementation Order (Phased)

### Phase 1 — Foundation (AI Service + Backend)
1. Add `NutrientLog` entity + Flyway migration
2. Add `POST /food/analyze-nutrients` endpoint in AI service (Gemini vision + text)
3. Add `GET /nutrient/daily-summary` + `/weekly-trends` endpoints in backend
4. Add RDA constants service in backend
5. Wire food log save to also trigger nutrient analysis

### Phase 2 — Recommendations (AI Service)
6. Add `UserNutrientPreferences` to user profile (region, cuisine, restrictions)
7. Onboarding flow to collect region + dietary preferences
8. Add `POST /nutrient/recommendations` endpoint (14-day deficiency → Gemini advice)
9. Infer cuisine style from food log history (majority vote on recognized cuisines)

### Phase 3 — Mobile UX
10. Add camera/text input to food log screen
11. Build nutrient breakdown card (shown post-log)
12. Build Nutrient Dashboard screen (weekly heatmap)
13. Integrate culturally-aware recommendations into Insights screen
14. Add deficiency alert notification (daily summary push)

---

## Files to Create / Modify

### Backend
```
backend/src/main/java/com/healthcoach/
  nutrient/
    NutrientLog.java              ← new entity
    NutrientLogRepository.java    ← new repo
    NutrientLogService.java       ← aggregation + RDA comparison
    NutrientController.java       ← REST endpoints
    dto/
      NutrientSummaryDTO.java
      NutrientRecommendationDTO.java
  food/
    FoodService.java              ← modified: trigger nutrient analysis post-save
  profile/
    UserPreferencesEntity.java    ← add region, cuisine, dietary_restrictions
```

### AI Service
```
ai-service/app/
  routers/
    nutrient_router.py            ← new: /food/analyze-nutrients, /nutrient/recommendations
  services/
    nutrient_analysis_service.py  ← new: Gemini vision/text → nutrient JSON
    recommendation_service.py     ← modified: add nutrient-aware recommendations
  schemas/
    nutrient.py                   ← new: NutrientProfile, FoodAnalysisRequest/Response
```

### Mobile
```
mobile/lib/features/
  food/
    presentation/
      food_log_screen.dart        ← modified: add camera + text describe buttons
      nutrient_breakdown_card.dart ← new widget
  nutrient_dashboard/
    nutrient_dashboard_screen.dart ← new screen
    nutrient_heatmap_widget.dart   ← new widget
  insights/
    insights_screen.dart          ← modified: add nutrition intelligence section
```

---

## Gemini Model Note

Use `gemini-2.5-flash` (already updated as default).
- Supports vision (image analysis) natively
- Fast JSON response mode
- Handles both food photo analysis AND recommendation generation

For image analysis, pass `PIL.Image` or base64 inline:
```python
contents = [system_prompt, {"mime_type": "image/jpeg", "data": base64_image}, user_prompt]
```

---

## Estimated Complexity

| Component | Effort | Priority |
|-----------|--------|----------|
| AI Service nutrient analysis endpoint | Medium | High |
| Backend NutrientLog entity + migrations | Small | High |
| Backend RDA constants + daily summary | Small | High |
| AI Service recommendations update | Medium | High |
| Mobile food log camera/text input | Medium | High |
| Mobile nutrient breakdown card | Small | High |
| Mobile nutrient dashboard screen | Large | Medium |
| User preference onboarding | Medium | Medium |
| Cuisine inference from history | Medium | Low |
| Push notifications for deficiencies | Small | Low |

---

*Plan created: 2026-03-02*
*Status: PENDING IMPLEMENTATION*
