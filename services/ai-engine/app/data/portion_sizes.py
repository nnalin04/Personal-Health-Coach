"""
Indian serving unit → grams lookup table.

Used by food analysis to resolve descriptions like "2 katoris of dal" → 300g
before nutrient lookup, so the LLM receives a concrete weight rather than
having to guess from vague portion language.

Usage:
    from app.data.portion_sizes import resolve_portion
    grams = resolve_portion("2 katoris")   # → 300.0
    grams = resolve_portion("1 mug")       # → None  (unrecognised)
"""
import re
from typing import Optional

# ── unit table ────────────────────────────────────────────────────────────────
# All keys lowercase. Aliases map to the same gram value.
INDIAN_UNITS: dict[str, float] = {
    # ── bowls / cups ──────────────────────────────────────────────────────────
    "katori":               150.0,
    "katorie":              150.0,
    "small bowl":           150.0,
    "small katori":         150.0,
    "medium katori":        200.0,
    "large katori":         250.0,
    "cup":                  240.0,
    "indian cup":           240.0,
    "bowl":                 200.0,
    "large bowl":           300.0,

    # ── spoons ────────────────────────────────────────────────────────────────
    "tablespoon":           15.0,
    "tbsp":                 15.0,
    "teaspoon":             5.0,
    "tsp":                  5.0,
    "ladle":                30.0,
    "serving spoon":        30.0,
    "kadchi":               30.0,   # ladle (Hindi)

    # ── Indian breads ─────────────────────────────────────────────────────────
    "roti":                 30.0,
    "roti (medium)":        30.0,
    "roti (large)":         40.0,
    "chapati":              30.0,
    "paratha":              60.0,
    "paratha (plain)":      60.0,
    "paratha (stuffed)":    80.0,
    "puri":                 25.0,
    "bhatura":              80.0,
    "naan":                 90.0,
    "kulcha":               70.0,
    "slice":                25.0,   # bread slice
    "bread slice":          25.0,

    # ── South Indian items ────────────────────────────────────────────────────
    "idli":                 40.0,
    "dosa":                 75.0,
    "dosa (plain)":         75.0,
    "dosa (masala)":        150.0,
    "vada":                 45.0,
    "medu vada":            45.0,
    "uttapam":              100.0,
    "appam":                60.0,

    # ── rice / grains ─────────────────────────────────────────────────────────
    "plate of rice":        200.0,
    "serving of rice":      150.0,

    # ── glasses / drinks ──────────────────────────────────────────────────────
    "glass":                200.0,
    "small glass":          150.0,
    "large glass":          300.0,
    "glass (200ml)":        200.0,
    "glass (250ml)":        250.0,

    # ── fruits ────────────────────────────────────────────────────────────────
    "medium fruit":         150.0,
    "small fruit":          100.0,
    "large fruit":          200.0,
    "medium apple":         150.0,
    "medium banana":        120.0,
    "medium mango":         200.0,
    "medium orange":        130.0,

    # ── snacks ────────────────────────────────────────────────────────────────
    "piece":                50.0,
    "slice (fruit)":        60.0,
}

# Sorted by length descending so multi-word keys match before single-word keys
_SORTED_UNITS = sorted(INDIAN_UNITS.keys(), key=len, reverse=True)

# Regex: optional number (int or float) followed by optional space and unit
_PORTION_RE = re.compile(
    r"^(\d+(?:\.\d+)?)\s*(.+)$",
    re.IGNORECASE,
)


def resolve_portion(description: str) -> Optional[float]:
    """
    Parse a human portion description and return total grams.

    Examples:
        "2 katoris"        → 300.0
        "1 tbsp"           → 15.0
        "3 rotis"          → 90.0
        "0.5 cup"          → 120.0
        "1 mug"            → None  (unrecognised unit)

    Returns None if the description cannot be parsed or the unit is unknown.
    """
    if not description:
        return None

    text = description.strip().lower()

    # Remove trailing plural 's' from unit (katoris → katori, rotis → roti)
    # but only if the result still matches a known unit
    m = _PORTION_RE.match(text)
    if not m:
        # Try matching without a leading number — treat as 1 unit
        unit_only = text.strip()
        grams = _lookup_unit(unit_only)
        return grams  # may be None

    quantity_str, unit_raw = m.group(1), m.group(2).strip()
    try:
        quantity = float(quantity_str)
    except ValueError:
        return None

    grams_per_unit = _lookup_unit(unit_raw)
    if grams_per_unit is None:
        return None

    return quantity * grams_per_unit


def _lookup_unit(unit: str) -> Optional[float]:
    """Look up a unit string against INDIAN_UNITS, trying de-pluralisation."""
    # Direct match
    if unit in INDIAN_UNITS:
        return INDIAN_UNITS[unit]

    # Try longest-prefix match from sorted keys
    for key in _SORTED_UNITS:
        if unit.startswith(key) or unit == key:
            return INDIAN_UNITS[key]

    # Try removing trailing 's' (simple plural)
    if unit.endswith("s") and len(unit) > 2:
        singular = unit[:-1]
        if singular in INDIAN_UNITS:
            return INDIAN_UNITS[singular]
        # Try longest-prefix again with singular
        for key in _SORTED_UNITS:
            if singular.startswith(key) or singular == key:
                return INDIAN_UNITS[key]

    return None
