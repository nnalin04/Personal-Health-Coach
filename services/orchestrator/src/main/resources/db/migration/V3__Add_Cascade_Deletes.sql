-- V3: Add ON DELETE CASCADE to all user-owned tables so DELETE /api/users/me
--     removes all user data in a single transaction.

-- medical_reports → users
ALTER TABLE medical_reports DROP CONSTRAINT fk_medical_report_user;
ALTER TABLE medical_reports ADD CONSTRAINT fk_medical_report_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- lab_values → medical_reports (cascade from report delete)
ALTER TABLE lab_values DROP CONSTRAINT fk_lab_values_report;
ALTER TABLE lab_values ADD CONSTRAINT fk_lab_values_report
    FOREIGN KEY (report_id) REFERENCES medical_reports(id) ON DELETE CASCADE;

-- workout_logs → users
ALTER TABLE workout_logs DROP CONSTRAINT fk_workout_user;
ALTER TABLE workout_logs ADD CONSTRAINT fk_workout_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- food_logs → users
ALTER TABLE food_logs DROP CONSTRAINT fk_food_user;
ALTER TABLE food_logs ADD CONSTRAINT fk_food_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- body_metrics → users
ALTER TABLE body_metrics DROP CONSTRAINT fk_body_metrics_user;
ALTER TABLE body_metrics ADD CONSTRAINT fk_body_metrics_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- steps → users
ALTER TABLE steps DROP CONSTRAINT fk_steps_user;
ALTER TABLE steps ADD CONSTRAINT fk_steps_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- health_goals → users
ALTER TABLE health_goals DROP CONSTRAINT fk_goals_user;
ALTER TABLE health_goals ADD CONSTRAINT fk_goals_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- nutrient_logs already has ON DELETE CASCADE (added in V2)
