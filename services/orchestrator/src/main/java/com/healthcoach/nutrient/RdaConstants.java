package com.healthcoach.nutrient;

import java.util.LinkedHashMap;
import java.util.Map;

public class RdaConstants {

    // RDA values per nutrient key → {male RDA, female RDA}
    // Units match the NutrientLog columns
    public record RdaValue(double male, double female, String unit) {}

    public static final Map<String, RdaValue> RDA = new LinkedHashMap<>();

    static {
        // Vitamins
        RDA.put("vitaminAMcg",   new RdaValue(900,  700,  "mcg"));
        RDA.put("vitaminB1Mg",   new RdaValue(1.2,  1.1,  "mg"));
        RDA.put("vitaminB2Mg",   new RdaValue(1.3,  1.1,  "mg"));
        RDA.put("vitaminB3Mg",   new RdaValue(16,   14,   "mg"));
        RDA.put("vitaminB6Mg",   new RdaValue(1.3,  1.3,  "mg"));
        RDA.put("vitaminB9Mcg",  new RdaValue(400,  400,  "mcg"));
        RDA.put("vitaminB12Mcg", new RdaValue(2.4,  2.4,  "mcg"));
        RDA.put("vitaminCMg",    new RdaValue(90,   75,   "mg"));
        RDA.put("vitaminDMcg",   new RdaValue(15,   15,   "mcg"));
        RDA.put("vitaminEMg",    new RdaValue(15,   15,   "mg"));
        RDA.put("vitaminKMcg",   new RdaValue(120,  90,   "mcg"));
        // Minerals
        RDA.put("calciumMg",     new RdaValue(1000, 1000, "mg"));
        RDA.put("ironMg",        new RdaValue(8,    18,   "mg"));
        RDA.put("zincMg",        new RdaValue(11,   8,    "mg"));
        RDA.put("magnesiumMg",   new RdaValue(420,  320,  "mg"));
        RDA.put("potassiumMg",   new RdaValue(3400, 2600, "mg"));
        RDA.put("seleniumMcg",   new RdaValue(55,   55,   "mcg"));
        RDA.put("iodineMcg",     new RdaValue(150,  150,  "mcg"));
    }

    public static double getRda(String key, String gender) {
        RdaValue v = RDA.get(key);
        if (v == null) return 0;
        return "female".equalsIgnoreCase(gender) ? v.female() : v.male();
    }
}
