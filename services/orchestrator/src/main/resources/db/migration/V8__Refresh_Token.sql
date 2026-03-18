-- V8: JWT refresh token store
--
-- Access tokens are now short-lived (1 hour).
-- Refresh tokens live 7 days and are stored here so they can be revoked.
-- Only the SHA-256 hash of the raw token is persisted — never the raw value.

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(64)  NOT NULL UNIQUE,   -- SHA-256 hex of the raw token
    expires_at  TIMESTAMP    NOT NULL,
    revoked     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id    ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
-- Periodic cleanup job can use this to delete expired+revoked rows
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
