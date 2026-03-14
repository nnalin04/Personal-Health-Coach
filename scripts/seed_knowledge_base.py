#!/usr/bin/env python3
"""
Knowledge Base Seeder — ICMR / FSSAI nutritional guidelines.

Seeds the `knowledge_base` table with curated health guidance chunks,
embeds each chunk with Gemini text-embedding-004 (768-dim), and stores
the result for pgvector cosine similarity search.

Usage:
    # Local (needs DB + GEMINI_API_KEY in environment):
    POSTGRES_HOST=localhost POSTGRES_PORT=5432 POSTGRES_DB=healthcoach \
    POSTGRES_USER=healthcoach POSTGRES_PASSWORD=<pw> \
    GEMINI_API_KEY=<key> python3 scripts/seed_knowledge_base.py

    # Via Docker (connects to running DB service):
    docker compose exec ai-engine python3 /app/scripts/seed_knowledge_base.py

The script is IDEMPOTENT: it checks `source` before inserting, so it is
safe to re-run after adding new chunks.
"""
import json
import logging
import os
import sys
import time

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ── Knowledge Chunks ───────────────────────────────────────────────────────────
# Each entry: { "content": str, "source": str, "category": str }
# Sources: ICMR Dietary Guidelines 2024, FSSAI RDA 2021, WHO South-East Asia

CHUNKS: list[dict] = [
    # ── Iron & Anaemia ─────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "iron_deficiency",
        "content": (
            "Iron deficiency anaemia is the most common nutritional deficiency in India, "
            "affecting over 50% of women and children. ICMR recommends 17 mg/day for adult men "
            "and 21 mg/day for adult women (higher during pregnancy: 35 mg/day). "
            "Good dietary sources include green leafy vegetables (spinach, methi, amaranth), "
            "legumes (rajma, chana, masoor dal), jaggery, and organ meats. "
            "Pair iron-rich foods with vitamin C sources (amla, tomato, lemon juice) to enhance "
            "non-haem iron absorption. Avoid tea or coffee within 1 hour of iron-rich meals."
        ),
    },
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "iron_deficiency",
        "content": (
            "Plant-based iron (non-haem) has lower bioavailability (2-20%) compared to haem iron "
            "from meat (15-35%). For vegetarians and vegans, strategies to improve absorption include: "
            "soaking and sprouting legumes to reduce phytates, fermenting foods (idli, dosa batter), "
            "cooking in cast iron vessels, and consuming vitamin C-rich foods at the same meal. "
            "Phytates in whole grains and oxalates in spinach can inhibit iron absorption — "
            "cooking reduces oxalate content significantly."
        ),
    },
    # ── Vitamin D ──────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "vitamin_d",
        "content": (
            "Despite abundant sunshine, vitamin D deficiency is paradoxically prevalent in India "
            "(40-80% of urban adults). ICMR RDA is 600 IU/day for adults; upper tolerable limit is "
            "4000 IU/day. Sunlight exposure of 10-15 minutes on face, arms, and legs between "
            "10 AM-2 PM (when UVB is sufficient) synthesises adequate vitamin D. "
            "Dietary sources are limited: fatty fish (mackerel, sardines, hilsa), egg yolk, "
            "fortified milk/yogurt, and mushrooms exposed to UV light. "
            "Supplementation is recommended for people with limited sun exposure, dark skin, "
            "obesity, or confirmed deficiency (serum 25-OH-D < 20 ng/mL)."
        ),
    },
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "vitamin_d",
        "content": (
            "Vitamin D deficiency is linked to osteoporosis, muscle weakness, increased fracture risk, "
            "impaired immunity, and depression. In India, high melanin content, extensive clothing, "
            "indoor lifestyles, and air pollution reduce UVB penetration. "
            "Fortified foods available in India include Amul milk (fortified D3), some breakfast cereals, "
            "and branded yogurt. Cod liver oil remains the most concentrated food source. "
            "For vegetarians, D2 (ergocalciferol from mushrooms) is less effective than D3 but still "
            "beneficial. Pair vitamin D with calcium and magnesium for optimal bone health."
        ),
    },
    # ── Calcium ────────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "calcium",
        "content": (
            "ICMR RDA for calcium: 800 mg/day for adults, 1000 mg/day for pregnant/lactating women, "
            "1200 mg/day for post-menopausal women. Best sources in Indian diet: milk (300 mg/240ml), "
            "curd/yogurt (300-400 mg/240ml), paneer (200 mg/100g), ragi/finger millet (344 mg/100g — "
            "highest among cereals), sesame seeds (975 mg/100g), til ladoo, amaranth leaves, "
            "drumstick leaves (moringa: 185 mg/100g). "
            "Calcium absorption requires adequate vitamin D; is reduced by excess sodium, caffeine, "
            "and phytates. Ragi (nachni) is particularly recommended for lactose-intolerant individuals "
            "and in rural diets across South India and Maharashtra."
        ),
    },
    # ── Vitamin B12 ────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "vitamin_b12",
        "content": (
            "Vitamin B12 is found almost exclusively in animal products — meat, fish, dairy, and eggs. "
            "ICMR RDA: 1 mcg/day for adults. Deficiency is extremely common in strict vegetarians and "
            "vegans in India (studies show 47% prevalence in vegetarians). "
            "Symptoms include megaloblastic anaemia, peripheral neuropathy, memory impairment, and "
            "elevated homocysteine (cardiovascular risk). "
            "Vegetarian sources (limited bioavailability): fortified foods (Amul B12 milk), "
            "nutritional yeast, fermented foods (idli/dosa may have trace amounts from bacterial synthesis). "
            "Supplementation (500-1000 mcg/week cyanocobalamin or methylcobalamin) is strongly "
            "recommended for all strict vegetarians and vegans."
        ),
    },
    # ── Protein ────────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "protein",
        "content": (
            "ICMR protein RDA: 0.8-1.0 g/kg body weight/day for sedentary adults; "
            "1.2-1.6 g/kg/day for physically active individuals; "
            "1.2-1.8 g/kg/day for athletes and muscle building. "
            "Complete protein sources in Indian vegetarian diet: combinations — "
            "dal + rice (complementary amino acids), curd + roti, rajma + rice, chana + wheat. "
            "Best animal sources: eggs (6g/egg, complete), chicken breast (31g/100g), "
            "fish, milk (3.4g/100ml). "
            "Best plant sources: moong dal (24g/100g dry), masoor dal (26g/100g dry), "
            "soybean/tofu (36g/100g dry), sattu (chana dal flour: 22g/100g), peanuts (26g/100g). "
            "Distribute protein intake across 3-4 meals for optimal muscle protein synthesis."
        ),
    },
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "protein",
        "content": (
            "India has a significant 'protein gap' — NSSO data shows average intake is only "
            "47-50g/day vs recommended 55-65g/day for a 60kg adult. "
            "Traditional Indian diets tend to be dal-centric but portion sizes are small. "
            "To increase protein: add a handful of nuts or seeds to breakfast, "
            "include an egg or cup of curd at lunch, increase dal portions, "
            "consider sattu sharbat (roasted gram flour) as a protein-rich drink. "
            "Whey protein supplements are effective but unnecessary if whole food intake is adequate."
        ),
    },
    # ── Fibre & Gut Health ─────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "fibre",
        "content": (
            "ICMR recommends 25-40g dietary fibre/day. Average Indian intake is only 15-20g/day. "
            "Fibre regulates blood sugar, reduces cholesterol, supports gut microbiome, and "
            "prevents constipation and colorectal cancer. "
            "High-fibre Indian foods: whole pulses (rajma, chana, lentils — 15g/cooked cup), "
            "vegetables (okra, broccoli, carrots), fruits (guava 9g, pear 5g, amla), "
            "whole grains (jowar, bajra, ragi — superior to refined wheat), "
            "psyllium husk (isabgol — 10g/tbsp). "
            "Gradually increase fibre intake with adequate water (2-3L/day) to prevent bloating."
        ),
    },
    # ── Omega-3 ────────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "omega3",
        "content": (
            "India has an alarming omega-6:omega-3 ratio (20-50:1 vs ideal 4:1) due to heavy use "
            "of sunflower/soybean oil. This imbalance increases cardiovascular and inflammatory disease risk. "
            "ICMR recommends 250mg/day EPA+DHA (marine omega-3) and 1.6-1.8g/day ALA (plant omega-3). "
            "Marine sources: hilsa (3g/100g), mackerel (2.6g/100g), sardines (2g/100g), "
            "salmon, rohu, katla. "
            "Plant ALA sources: flaxseeds/alsi (23g/100g), chia seeds (18g/100g), walnuts (9g/100g), "
            "perilla seeds, methi seeds. "
            "Use mustard oil or flaxseed oil for cooking to improve omega-3:6 ratio. "
            "ALA conversion to EPA/DHA is only 5-10%, so marine sources are far superior."
        ),
    },
    # ── Diabetes / Blood Sugar ─────────────────────────────────────────────────
    {
        "source": "ICMR_NIN_diabetes_guidelines_2023",
        "category": "diabetes",
        "content": (
            "India has 101 million people with diabetes (IDF 2021) — the highest globally. "
            "Dietary management: choose low glycemic index (GI) foods. "
            "Low-GI Indian foods: oats (55), moong dal (29), rajma (24), barley (28), "
            "basmati rice (57 — lower than regular rice), ragi (68), bitter gourd (karela), "
            "fenugreek seeds (methi — reduces post-meal blood sugar by 10-15%). "
            "High-GI foods to limit: white rice (72), maida/refined flour (85), "
            "potato (85), white bread (75), sugary drinks. "
            "Portion control, distributing carbs across 3-4 meals, including protein + fat + fibre "
            "at each meal, and walking 10 minutes after eating all reduce post-meal glucose spikes."
        ),
    },
    {
        "source": "ICMR_NIN_diabetes_guidelines_2023",
        "category": "diabetes",
        "content": (
            "For pre-diabetes and type 2 diabetes management: "
            "ICMR recommends a plate method — 50% non-starchy vegetables, 25% lean protein, "
            "25% complex carbohydrates. "
            "Specific South Indian adjustments: replace white rice with brown rice or millet (ragi, bajra); "
            "make idli/dosa with added ragi or oats; use coconut milk sparingly (high in saturated fat); "
            "avoid sweet chutneys and sambhar with excess jaggery. "
            "For North India: replace maida rotis with whole wheat + ragi flour blend; "
            "reduce portion of rice/roti; add moong dal chilla as protein-rich breakfast. "
            "Regular aerobic exercise (150 min/week) combined with strength training is synergistic "
            "with dietary intervention for blood sugar control."
        ),
    },
    # ── Hypertension / Heart Health ────────────────────────────────────────────
    {
        "source": "ICMR_cardiovascular_guidelines_2023",
        "category": "hypertension",
        "content": (
            "India's average sodium intake is 8-12g/day vs WHO recommended <5g/day. "
            "Reducing sodium is the single most effective dietary intervention for hypertension. "
            "Practical Indian strategies: use less salt during cooking (taste before adding more), "
            "avoid adding table salt, limit pickles (achar), papads, canned foods, processed snacks. "
            "DASH diet adapted for India: emphasise potassium-rich foods (banana, coconut water, "
            "sweet potato, spinach, amla), magnesium (pumpkin seeds, dark chocolate, almonds), "
            "and calcium (dairy, ragi). "
            "The ICMR-endorsed DASH-India diet reduces systolic BP by 8-14 mmHg. "
            "Limit alcohol; quit smoking; achieve or maintain healthy BMI (18.5-22.9 for Asian Indians)."
        ),
    },
    # ── Weight Management ──────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "weight_management",
        "content": (
            "ICMR-recommended BMI for Indian adults: 18.5-22.9 kg/m² (lower than WHO 25 due to "
            "higher visceral fat at lower BMI in South Asians). "
            "For weight loss: a 500-750 kcal/day deficit leads to 0.5-1kg/week loss. "
            "Calorie targets: sedentary women 1500-1800 kcal/day; sedentary men 1800-2200 kcal/day. "
            "High-satiety Indian foods for weight management: dal tadka (high protein + fibre), "
            "curd/buttermilk (probiotic, low calorie), salads with chaat masala, "
            "grilled/baked snacks instead of fried, makhana (fox nuts — 347 kcal/100g but very filling), "
            "whole fruits instead of juices. "
            "Avoid: fried snacks (samosa, bhatura, puri), sweets (mithai, gulab jamun, barfi), "
            "fruit juices (high sugar), sweetened lassi, chai with sugar."
        ),
    },
    # ── Gut Health / Probiotics ────────────────────────────────────────────────
    {
        "source": "FSSAI_functional_foods_2022",
        "category": "gut_health",
        "content": (
            "India has a rich tradition of fermented probiotic foods that support gut microbiome health. "
            "Key probiotic Indian foods: curd/dahi (Lactobacillus acidophilus), "
            "chaas/buttermilk (diluted curd — easier to digest), "
            "idli and dosa (fermented rice + urad dal — Leuconostoc mesenteroides), "
            "kanji (fermented carrot/beet drink from North India), "
            "gundruk (fermented leafy vegetable from North East), "
            "sinki (fermented radish taproot from Sikkim). "
            "Prebiotic foods that feed beneficial bacteria: raw garlic, onion, banana, "
            "green banana flour, whole oats, asparagus. "
            "A healthy gut microbiome is linked to improved immunity, mood regulation, "
            "reduced inflammation, and better weight management."
        ),
    },
    # ── Hydration ─────────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "hydration",
        "content": (
            "ICMR recommends 2.5-3.5 litres of total fluid intake per day for Indian adults, "
            "higher in hot humid climates and during exercise. "
            "Dehydration of even 2% body weight impairs cognitive performance by 10-15%. "
            "Best hydrating beverages for India: plain water, nimbu pani (lemon water — electrolytes), "
            "coconut water (natural electrolytes, low calorie), chaas/buttermilk (cools the body), "
            "aam panna (raw mango drink — vitamin C + electrolytes for summer). "
            "Limit: sweetened sodas, packaged fruit juices, excessive chai/coffee (mild diuretics). "
            "Signs of adequate hydration: pale yellow urine. "
            "Increase intake during monsoon, when ill with fever/diarrhoea, and during physical activity."
        ),
    },
    # ── Pregnancy & Lactation ──────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "pregnancy",
        "content": (
            "During pregnancy, ICMR recommends additional 350 kcal/day (2nd trimester) and "
            "450 kcal/day (3rd trimester) above baseline. Key nutrients: "
            "Folate (400-600 mcg/day) — green leafy vegetables, dal, fortified foods; "
            "Iron (35 mg/day vs 21 for non-pregnant women); "
            "Calcium (1000-1200 mg/day); Iodine (220 mcg/day) — iodised salt; "
            "DHA (200 mg/day) — fish 2x/week or supplement. "
            "Foods to avoid in pregnancy: raw papaya, pineapple (may stimulate contractions), "
            "unpasteurised milk/soft cheese, high-mercury fish (shark, swordfish), "
            "excess vitamin A (liver, fish oil > 3000 mcg/day), alcohol, caffeine > 200mg/day. "
            "Morning sickness remedies: ginger tea, small frequent meals, bland foods, cold foods."
        ),
    },
    # ── Thyroid Health ─────────────────────────────────────────────────────────
    {
        "source": "ICMR_dietary_guidelines_2024",
        "category": "thyroid",
        "content": (
            "Iodine deficiency is the leading preventable cause of brain damage globally and "
            "remains endemic in Himalayan and sub-Himalayan India. "
            "ICMR RDA for iodine: 150 mcg/day for adults, 220 mcg/day in pregnancy. "
            "Use iodised salt (not rock salt or sea salt, which lack iodine) for all cooking. "
            "Goitrogenic foods reduce iodine utilisation — broccoli, cauliflower, cabbage, kale, "
            "soy, millets contain goitrogens; cooking reduces their effect by 30-90%. "
            "For hypothyroidism: selenium (Brazil nuts, sunflower seeds) supports T4→T3 conversion. "
            "Zinc (pumpkin seeds, sesame, chickpeas) is also important for thyroid hormone synthesis. "
            "Those on levothyroxine should take it on an empty stomach, 30 min before eating."
        ),
    },
]


# ── Embedding + DB helpers ─────────────────────────────────────────────────────

def get_embedding(text: str, api_key: str) -> list[float] | None:
    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        result = genai.embed_content(
            model     = "models/text-embedding-004",
            content   = text,
            task_type = "RETRIEVAL_DOCUMENT",
        )
        return result["embedding"]
    except Exception as e:
        logger.error("Embedding failed: %s", e)
        return None


def get_db_conn():
    import psycopg2
    return psycopg2.connect(
        host     = os.getenv("POSTGRES_HOST", "localhost"),
        port     = int(os.getenv("POSTGRES_PORT", "5432")),
        dbname   = os.getenv("POSTGRES_DB",   "healthcoach"),
        user     = os.getenv("POSTGRES_USER",  "healthcoach"),
        password = os.getenv("POSTGRES_PASSWORD", ""),
    )


def seed():
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        logger.error("GEMINI_API_KEY not set — cannot generate embeddings.")
        sys.exit(1)

    conn = get_db_conn()
    inserted = 0
    skipped  = 0

    try:
        with conn:
            with conn.cursor() as cur:
                for chunk in CHUNKS:
                    # Idempotency: skip if same source + first 100 chars of content already exists
                    cur.execute(
                        "SELECT 1 FROM knowledge_base WHERE source = %s AND content LIKE %s LIMIT 1",
                        (chunk["source"], chunk["content"][:100] + "%"),
                    )
                    if cur.fetchone():
                        logger.info("SKIP (exists): %s | %s", chunk["source"], chunk["category"])
                        skipped += 1
                        continue

                    logger.info("Embedding: %s | %s ...", chunk["source"], chunk["category"])
                    embedding = get_embedding(chunk["content"], api_key)
                    if embedding is None:
                        logger.warning("Skipping chunk due to embedding failure")
                        skipped += 1
                        continue

                    vec_str = "[" + ",".join(str(v) for v in embedding) + "]"
                    cur.execute(
                        """INSERT INTO knowledge_base (content, source, category, embedding)
                           VALUES (%s, %s, %s, %s::vector)""",
                        (chunk["content"], chunk["source"], chunk["category"], vec_str),
                    )
                    inserted += 1
                    logger.info("Inserted chunk %d/%d", inserted, len(CHUNKS))
                    time.sleep(0.5)  # rate-limit Gemini embed API

        logger.info("Done. Inserted: %d | Skipped: %d | Total chunks: %d", inserted, skipped, len(CHUNKS))
    finally:
        conn.close()


if __name__ == "__main__":
    import os
    seed()
