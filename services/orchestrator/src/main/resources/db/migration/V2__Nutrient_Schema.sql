-- V2: Nutrient Intelligence Schema

-- Add user preference columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS region VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS cuisine_style VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS dietary_restrictions TEXT;

-- Nutrient logs table (one row per food log entry, stores micronutrients)
CREATE TABLE IF NOT EXISTS nutrient_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    food_log_id BIGINT REFERENCES food_logs(id) ON DELETE SET NULL,
    log_date DATE NOT NULL,
    -- Vitamins
    vitamin_a_mcg DOUBLE PRECISION,
    vitamin_b1_mg DOUBLE PRECISION,
    vitamin_b2_mg DOUBLE PRECISION,
    vitamin_b3_mg DOUBLE PRECISION,
    vitamin_b6_mg DOUBLE PRECISION,
    vitamin_b9_mcg DOUBLE PRECISION,
    vitamin_b12_mcg DOUBLE PRECISION,
    vitamin_c_mg DOUBLE PRECISION,
    vitamin_d_mcg DOUBLE PRECISION,
    vitamin_e_mg DOUBLE PRECISION,
    vitamin_k_mcg DOUBLE PRECISION,
    -- Minerals
    calcium_mg DOUBLE PRECISION,
    iron_mg DOUBLE PRECISION,
    zinc_mg DOUBLE PRECISION,
    magnesium_mg DOUBLE PRECISION,
    potassium_mg DOUBLE PRECISION,
    selenium_mcg DOUBLE PRECISION,
    iodine_mcg DOUBLE PRECISION,
    -- Metadata
    food_description TEXT,
    confidence DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nutrient_logs_user_date ON nutrient_logs(user_id, log_date);
