"""
ICMR 2020 Recommended Dietary Allowances for the Indian population.

Source: Indian Council of Medical Research — Nutrient Requirements for Indians (2020)
https://www.nin.res.in/

Key differences from WHO/Western standards:
  - Iron adult woman: 29 mg/day (vs WHO 18 mg/day) — lower bioavailability in plant-heavy diets
  - Vitamin C adult: 40 mg/day (vs WHO 65-90 mg) — ICMR is conservative; Indian diets are rich in C
  - Vitamin B12 adult: 1.0 mcg/day (vs WHO 2.4 mcg) — ICMR reflects Indian absorption patterns
  - Zinc adult man: 12 mg/day; adult woman: 10 mg/day

Use get_rda(gender, age) to retrieve the correct profile.
Use get_rda_percentage(nutrient, value, gender, age) for deficiency % calculations.
"""
from typing import Optional

# ── RDA table ─────────────────────────────────────────────────────────────────
# Keys: (gender, age_group) → nutrient → value
# Gender: "male" | "female"
# Age groups follow ICMR 2020 classification

ICMR_RDA: dict[tuple[str, str], dict[str, float]] = {

    # ── Child 1–3 years ───────────────────────────────────────────────────────
    ("male", "child_1_3"): {
        "iron_mg": 9.0, "calcium_mg": 500.0, "zinc_mg": 5.0, "magnesium_mg": 60.0,
        "potassium_mg": 700.0, "vitamin_a_mcg": 400.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 5.0, "vitamin_b12_mcg": 0.5,
        "vitamin_b6_mg": 0.5, "vitamin_b9_mcg": 80.0, "vitamin_b1_mg": 0.5,
        "vitamin_b2_mg": 0.6, "vitamin_b3_mg": 6.0,
    },
    ("female", "child_1_3"): {
        "iron_mg": 9.0, "calcium_mg": 500.0, "zinc_mg": 5.0, "magnesium_mg": 60.0,
        "potassium_mg": 700.0, "vitamin_a_mcg": 400.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 5.0, "vitamin_b12_mcg": 0.5,
        "vitamin_b6_mg": 0.5, "vitamin_b9_mcg": 80.0, "vitamin_b1_mg": 0.5,
        "vitamin_b2_mg": 0.6, "vitamin_b3_mg": 6.0,
    },

    # ── Child 4–6 years ───────────────────────────────────────────────────────
    ("male", "child_4_6"): {
        "iron_mg": 13.0, "calcium_mg": 600.0, "zinc_mg": 6.0, "magnesium_mg": 76.0,
        "potassium_mg": 900.0, "vitamin_a_mcg": 400.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 6.0, "vitamin_b12_mcg": 0.7,
        "vitamin_b6_mg": 0.6, "vitamin_b9_mcg": 100.0, "vitamin_b1_mg": 0.6,
        "vitamin_b2_mg": 0.7, "vitamin_b3_mg": 8.0,
    },
    ("female", "child_4_6"): {
        "iron_mg": 13.0, "calcium_mg": 600.0, "zinc_mg": 6.0, "magnesium_mg": 76.0,
        "potassium_mg": 900.0, "vitamin_a_mcg": 400.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 6.0, "vitamin_b12_mcg": 0.7,
        "vitamin_b6_mg": 0.6, "vitamin_b9_mcg": 100.0, "vitamin_b1_mg": 0.6,
        "vitamin_b2_mg": 0.7, "vitamin_b3_mg": 8.0,
    },

    # ── Child 7–9 years ───────────────────────────────────────────────────────
    ("male", "child_7_9"): {
        "iron_mg": 16.0, "calcium_mg": 700.0, "zinc_mg": 7.0, "magnesium_mg": 100.0,
        "potassium_mg": 1200.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 7.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 0.9, "vitamin_b9_mcg": 130.0, "vitamin_b1_mg": 0.8,
        "vitamin_b2_mg": 1.0, "vitamin_b3_mg": 10.0,
    },
    ("female", "child_7_9"): {
        "iron_mg": 16.0, "calcium_mg": 700.0, "zinc_mg": 7.0, "magnesium_mg": 100.0,
        "potassium_mg": 1200.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 7.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 0.9, "vitamin_b9_mcg": 130.0, "vitamin_b1_mg": 0.8,
        "vitamin_b2_mg": 1.0, "vitamin_b3_mg": 10.0,
    },

    # ── Child 10–12 years ─────────────────────────────────────────────────────
    ("male", "child_10_12"): {
        "iron_mg": 21.0, "calcium_mg": 800.0, "zinc_mg": 9.0, "magnesium_mg": 200.0,
        "potassium_mg": 1500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 8.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.0, "vitamin_b9_mcg": 150.0, "vitamin_b1_mg": 1.0,
        "vitamin_b2_mg": 1.2, "vitamin_b3_mg": 12.0,
    },
    ("female", "child_10_12"): {
        "iron_mg": 27.0, "calcium_mg": 800.0, "zinc_mg": 9.0, "magnesium_mg": 200.0,
        "potassium_mg": 1500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 8.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.0, "vitamin_b9_mcg": 150.0, "vitamin_b1_mg": 1.0,
        "vitamin_b2_mg": 1.2, "vitamin_b3_mg": 12.0,
    },

    # ── Adolescent 13–15 years ────────────────────────────────────────────────
    ("male", "adolescent_13_15"): {
        "iron_mg": 32.0, "calcium_mg": 800.0, "zinc_mg": 11.0, "magnesium_mg": 270.0,
        "potassium_mg": 2300.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.3, "vitamin_b9_mcg": 200.0, "vitamin_b1_mg": 1.2,
        "vitamin_b2_mg": 1.5, "vitamin_b3_mg": 15.0,
    },
    ("female", "adolescent_13_15"): {
        "iron_mg": 27.0, "calcium_mg": 800.0, "zinc_mg": 10.0, "magnesium_mg": 240.0,
        "potassium_mg": 2300.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.2, "vitamin_b9_mcg": 200.0, "vitamin_b1_mg": 1.0,
        "vitamin_b2_mg": 1.2, "vitamin_b3_mg": 13.0,
    },

    # ── Adolescent 16–18 years ────────────────────────────────────────────────
    ("male", "adolescent_16_18"): {
        "iron_mg": 28.0, "calcium_mg": 800.0, "zinc_mg": 12.0, "magnesium_mg": 300.0,
        "potassium_mg": 2700.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.3, "vitamin_b9_mcg": 200.0, "vitamin_b1_mg": 1.2,
        "vitamin_b2_mg": 1.5, "vitamin_b3_mg": 16.0,
    },
    ("female", "adolescent_16_18"): {
        "iron_mg": 26.0, "calcium_mg": 800.0, "zinc_mg": 10.0, "magnesium_mg": 240.0,
        "potassium_mg": 2700.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.2, "vitamin_b9_mcg": 200.0, "vitamin_b1_mg": 1.0,
        "vitamin_b2_mg": 1.2, "vitamin_b3_mg": 14.0,
    },

    # ── Adult (19–50 years) ───────────────────────────────────────────────────
    ("male", "adult"): {
        "iron_mg": 17.0, "calcium_mg": 1000.0, "zinc_mg": 12.0, "magnesium_mg": 340.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.6, "vitamin_b9_mcg": 220.0, "vitamin_b1_mg": 1.2,
        "vitamin_b2_mg": 1.4, "vitamin_b3_mg": 16.0,
    },
    ("female", "adult"): {
        "iron_mg": 29.0, "calcium_mg": 1000.0, "zinc_mg": 10.0, "magnesium_mg": 310.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.6, "vitamin_b9_mcg": 220.0, "vitamin_b1_mg": 1.1,
        "vitamin_b2_mg": 1.3, "vitamin_b3_mg": 14.0,
    },

    # ── Elderly (51+ years) ───────────────────────────────────────────────────
    ("male", "elderly"): {
        "iron_mg": 17.0, "calcium_mg": 1000.0, "zinc_mg": 12.0, "magnesium_mg": 340.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 20.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.6, "vitamin_b9_mcg": 220.0, "vitamin_b1_mg": 1.2,
        "vitamin_b2_mg": 1.4, "vitamin_b3_mg": 16.0,
    },
    ("female", "elderly"): {
        "iron_mg": 17.0, "calcium_mg": 1000.0, "zinc_mg": 10.0, "magnesium_mg": 310.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 600.0, "vitamin_c_mg": 40.0,
        "vitamin_d_mcg": 20.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.0,
        "vitamin_b6_mg": 1.6, "vitamin_b9_mcg": 220.0, "vitamin_b1_mg": 1.1,
        "vitamin_b2_mg": 1.3, "vitamin_b3_mg": 14.0,
    },

    # ── Pregnant ──────────────────────────────────────────────────────────────
    ("female", "pregnant"): {
        "iron_mg": 35.0, "calcium_mg": 1200.0, "zinc_mg": 12.0, "magnesium_mg": 370.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 800.0, "vitamin_c_mg": 60.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 10.0, "vitamin_b12_mcg": 1.2,
        "vitamin_b6_mg": 2.0, "vitamin_b9_mcg": 500.0, "vitamin_b1_mg": 1.5,
        "vitamin_b2_mg": 1.7, "vitamin_b3_mg": 18.0,
    },

    # ── Lactating ─────────────────────────────────────────────────────────────
    ("female", "lactating"): {
        "iron_mg": 21.0, "calcium_mg": 1200.0, "zinc_mg": 12.0, "magnesium_mg": 360.0,
        "potassium_mg": 3500.0, "vitamin_a_mcg": 950.0, "vitamin_c_mg": 80.0,
        "vitamin_d_mcg": 15.0, "vitamin_e_mg": 12.0, "vitamin_b12_mcg": 1.5,
        "vitamin_b6_mg": 2.2, "vitamin_b9_mcg": 300.0, "vitamin_b1_mg": 1.5,
        "vitamin_b2_mg": 1.8, "vitamin_b3_mg": 17.0,
    },
}


# ── helpers ───────────────────────────────────────────────────────────────────

def _age_to_group(age: Optional[int]) -> str:
    if age is None:
        return "adult"
    if age <= 3:   return "child_1_3"
    if age <= 6:   return "child_4_6"
    if age <= 9:   return "child_7_9"
    if age <= 12:  return "child_10_12"
    if age <= 15:  return "adolescent_13_15"
    if age <= 18:  return "adolescent_16_18"
    if age <= 50:  return "adult"
    return "elderly"


def get_rda(gender: str, age: Optional[int]) -> dict:
    """
    Return the ICMR 2020 RDA dict for the given gender and age.

    Args:
        gender: "male" | "female" (case-insensitive; defaults to "male" if unknown)
        age:    Age in years, or None (defaults to adult)

    Returns:
        Dict mapping nutrient name → RDA value.
    """
    g = gender.lower() if gender else "male"
    if g not in ("male", "female"):
        g = "male"

    age_group = _age_to_group(age)

    # Pregnant/lactating states must be set explicitly (age-based lookup can't infer them)
    key = (g, age_group)
    if key in ICMR_RDA:
        return ICMR_RDA[key].copy()

    # Fallback: adult male
    return ICMR_RDA[("male", "adult")].copy()


def get_rda_percentage(
    nutrient: str,
    value: float,
    gender: str,
    age: Optional[int],
) -> float:
    """
    Return the percentage of RDA met, capped at 200% to avoid outlier spikes.

    Args:
        nutrient: Nutrient key (e.g. "iron_mg", "vitamin_c_mg")
        value:    Actual intake value
        gender:   "male" | "female"
        age:      Age in years or None

    Returns:
        Percentage (0–200).
    """
    rda = get_rda(gender, age)
    rda_value = rda.get(nutrient, 0.0)
    if rda_value <= 0:
        return 0.0
    pct = (value / rda_value) * 100.0
    return min(pct, 200.0)
