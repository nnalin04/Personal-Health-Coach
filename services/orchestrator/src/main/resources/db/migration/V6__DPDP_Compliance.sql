-- V6: DPDP (Digital Personal Data Protection Act 2023) compliance
-- Adds consent tracking and application-level encryption support
-- for sensitive health data fields.

-- ── pgcrypto for field-level AES-256 encryption ───────────────────────────
-- Used by EncryptionService to store encrypted lab_values and report_text.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Consent version tracking on users ────────────────────────────────────
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS consent_version      VARCHAR(10),
    ADD COLUMN IF NOT EXISTS withdrawal_requested BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS withdrawal_at        TIMESTAMP;

-- ── Consent audit log ─────────────────────────────────────────────────────
-- Immutable record of every consent accept/withdraw event per user.
CREATE TABLE IF NOT EXISTS consent_records (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type        VARCHAR(20) NOT NULL CHECK (event_type IN ('ACCEPT', 'WITHDRAW')),
    consent_version   VARCHAR(10) NOT NULL,
    ip_address        VARCHAR(45),
    user_agent        TEXT,
    created_at        TIMESTAMP   NOT NULL DEFAULT NOW(),
    withdrawal_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_consent_records_user_id ON consent_records(user_id);
CREATE INDEX IF NOT EXISTS idx_consent_records_created ON consent_records(created_at);

-- ── Encrypted medical fields ──────────────────────────────────────────────
-- raw_text and lab_values_json hold PII health data; encrypt at rest.
-- The application layer (EncryptionService) reads/writes these as
-- pgp_sym_encrypt / pgp_sym_decrypt using the app.encryption.key env var.
-- Columns renamed with _enc suffix to signal they hold ciphertext.
ALTER TABLE medical_reports
    ADD COLUMN IF NOT EXISTS raw_text_enc        TEXT,
    ADD COLUMN IF NOT EXISTS lab_values_enc      TEXT;

-- Migrate existing plaintext if any rows already exist
UPDATE medical_reports
SET raw_text_enc   = raw_text,
    lab_values_enc = lab_values_json
WHERE raw_text IS NOT NULL
   OR lab_values_json IS NOT NULL;

COMMENT ON COLUMN medical_reports.raw_text_enc   IS 'AES-256-GCM encrypted raw OCR text (application-level)';
COMMENT ON COLUMN medical_reports.lab_values_enc IS 'AES-256-GCM encrypted JSON lab values (application-level)';
