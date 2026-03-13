-- ============================================================
-- V5: Health OS Phase 1 — pgvector, Taste Profiles, Knowledge Base
-- ============================================================

-- Enable pgvector extension (requires pgvector/pgvector:pg16 image)
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable pgcrypto for AES-256 field-level encryption (DPDP Act compliance)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Taste Profiles ──────────────────────────────────────────
-- Captures cultural + dietary preferences used by the AI for
-- regional food recommendations and vision analysis filtering.
CREATE TABLE IF NOT EXISTS taste_profiles (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    region               VARCHAR(100),
    staple_grains        VARCHAR(100),
    cuisine_style        VARCHAR(100),
    dietary_restrictions VARCHAR(255),
    health_goal          VARCHAR(255),
    spice_preference     VARCHAR(20)  CHECK (spice_preference IN ('mild','medium','spicy')),
    meal_frequency       SMALLINT     CHECK (meal_frequency BETWEEN 2 AND 6),
    allergies            TEXT[],
    -- DPDP Act consent tracking
    consent_version      VARCHAR(20)  NOT NULL DEFAULT '1.0',
    withdrawal_requested BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMP    NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX idx_taste_profiles_user ON taste_profiles(user_id);

-- ── RAG Knowledge Base ───────────────────────────────────────
-- Stores health advice chunks with 1536-dim embeddings (text-embedding-004).
-- HNSW index for low-latency cosine similarity search on Dashboard.
CREATE TABLE IF NOT EXISTS knowledge_base (
    id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    content   TEXT    NOT NULL,
    source    VARCHAR(255),           -- e.g. 'ICMR_guidelines_2023', 'FSSAI_rda'
    category  VARCHAR(100),           -- e.g. 'iron_deficiency', 'vitamin_d', 'diabetes'
    embedding VECTOR(1536),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- HNSW index: superior recall + low latency for real-time dashboard suggestions
CREATE INDEX idx_kb_embedding_hnsw ON knowledge_base
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE INDEX idx_kb_category ON knowledge_base(category);

-- ── Omni-Chat Tasks ──────────────────────────────────────────
-- Tracks async tasks published to RabbitMQ. WebSocket notifies
-- mobile when status changes to COMPLETED or FAILED.
CREATE TABLE IF NOT EXISTS omni_chat_tasks (
    id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         BIGINT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    chat_id         VARCHAR(100) NOT NULL,
    task_type       VARCHAR(20)  NOT NULL CHECK (task_type IN ('FOOD','REPORT','TEXT','RAG')),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PROCESSING'
                                 CHECK (status IN ('PROCESSING','COMPLETED','FAILED','PARTIAL')),
    payload_url     VARCHAR(500),   -- GCS URL for food image / medical PDF
    result_json     JSONB,          -- parsed AI response stored here on completion
    error_message   TEXT,
    estimated_secs  SMALLINT    DEFAULT 5,
    created_at      TIMESTAMP   NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMP
);

CREATE INDEX idx_tasks_user_status ON omni_chat_tasks(user_id, status);
CREATE INDEX idx_tasks_chat        ON omni_chat_tasks(chat_id);

-- ── WatermelonDB Sync Support ────────────────────────────────
-- Track last-modified timestamps so pull/push endpoints can
-- return deltas efficiently.
ALTER TABLE food_logs     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();
ALTER TABLE workout_logs  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();
ALTER TABLE body_metrics  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();
ALTER TABLE step_logs     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();
ALTER TABLE medical_reports ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();

-- Partial indexes for efficient sync delta queries
CREATE INDEX IF NOT EXISTS idx_food_updated     ON food_logs(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_workout_updated  ON workout_logs(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_body_updated     ON body_metrics(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_steps_updated    ON step_logs(user_id, updated_at);
