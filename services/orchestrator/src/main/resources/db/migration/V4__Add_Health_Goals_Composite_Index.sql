-- Add composite index on (user_id, completed) for goal queries that filter
-- by both user and completion status (findByUserIdAndCompletedFalse).
-- idx_goals_user (user_id only) already exists from V1.
CREATE INDEX IF NOT EXISTS idx_health_goals_user_completed ON health_goals(user_id, completed);
