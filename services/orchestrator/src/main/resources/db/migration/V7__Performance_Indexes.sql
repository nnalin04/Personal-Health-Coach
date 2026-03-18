-- V7: Performance indexes for WatermelonDB sync and list queries
--
-- Problem: sync pull runs 4 sequential full-table scans filtered by (user_id, updated_at).
-- On a 1-year account with 1,000 food logs, each scan reads O(n) rows.
-- Composite indexes on (user_id, updated_at) reduce this to O(log n + k) where k = changed rows.
--
-- Also adds missing composite index on date-range queries used by the list endpoints.

-- ── food_logs ─────────────────────────────────────────────────────────────────

-- Sync pull: WHERE user_id = ? AND updated_at > ?
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_food_logs_user_updated_at
    ON food_logs (user_id, updated_at);

-- List endpoint: WHERE user_id = ? AND date BETWEEN ? AND ? ORDER BY date DESC
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_food_logs_user_date
    ON food_logs (user_id, date DESC);

-- ── workout_logs ──────────────────────────────────────────────────────────────

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workout_logs_user_updated_at
    ON workout_logs (user_id, updated_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workout_logs_user_date
    ON workout_logs (user_id, date DESC);

-- ── body_metrics ──────────────────────────────────────────────────────────────

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_body_metrics_user_updated_at
    ON body_metrics (user_id, updated_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_body_metrics_user_date
    ON body_metrics (user_id, date DESC);

-- ── step_logs ─────────────────────────────────────────────────────────────────

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_step_logs_user_updated_at
    ON step_logs (user_id, updated_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_step_logs_user_date
    ON step_logs (user_id, date DESC);

-- ── omni_chat_tasks ───────────────────────────────────────────────────────────
-- Polling fallback: WHERE user_id = ? AND status = ?
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_omni_chat_tasks_user_status
    ON omni_chat_tasks (user_id, status);

-- ── Expected query plan improvement ───────────────────────────────────────────
-- Before: Seq Scan on food_logs (cost=0.00..25.00 rows=1000 width=...)
-- After:  Index Scan using idx_food_logs_user_updated_at (cost=0.15..8.20 rows=3 width=...)
