-- Initial Schema for Personal Health Coach

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    age INTEGER,
    gender VARCHAR(255),
    height DOUBLE PRECISION,
    goal VARCHAR(255),
    diet_type VARCHAR(255),
    medical_flags TEXT,
    role VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

CREATE TABLE medical_reports (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    report_file_path VARCHAR(255) NOT NULL,
    report_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_medical_report_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_medical_report_user_date ON medical_reports(user_id, report_date);

CREATE TABLE lab_values (
    id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL,
    vitamin_d DOUBLE PRECISION,
    tsh DOUBLE PRECISION,
    ldl DOUBLE PRECISION,
    hdl DOUBLE PRECISION,
    triglycerides DOUBLE PRECISION,
    hba1c DOUBLE PRECISION,
    creatinine DOUBLE PRECISION,
    hemoglobin DOUBLE PRECISION,
    alt DOUBLE PRECISION,
    ast DOUBLE PRECISION,
    glucose DOUBLE PRECISION,
    testosterone DOUBLE PRECISION,
    CONSTRAINT fk_lab_values_report FOREIGN KEY (report_id) REFERENCES medical_reports(id)
);

CREATE INDEX idx_lab_values_report ON lab_values(report_id);

CREATE TABLE workout_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    exercise_name VARCHAR(255) NOT NULL,
    sets INTEGER,
    reps INTEGER,
    weight DOUBLE PRECISION,
    date DATE NOT NULL,
    CONSTRAINT fk_workout_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_workout_user_date ON workout_logs(user_id, date);

CREATE TABLE food_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    meal_type VARCHAR(255) NOT NULL,
    food_name VARCHAR(255) NOT NULL,
    protein DOUBLE PRECISION NOT NULL,
    carbs DOUBLE PRECISION NOT NULL,
    fats DOUBLE PRECISION NOT NULL,
    calories DOUBLE PRECISION NOT NULL,
    date DATE NOT NULL,
    CONSTRAINT fk_food_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_food_user_date ON food_logs(user_id, date);

CREATE TABLE body_metrics (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    weight DOUBLE PRECISION NOT NULL,
    bmi DOUBLE PRECISION,
    body_fat DOUBLE PRECISION,
    muscle_mass DOUBLE PRECISION,
    date DATE NOT NULL,
    CONSTRAINT fk_body_metrics_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_body_metrics_user_date ON body_metrics(user_id, date);

CREATE TABLE steps (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    step_count INTEGER NOT NULL,
    date DATE NOT NULL,
    CONSTRAINT fk_steps_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_steps_user_date ON steps(user_id, date);

CREATE TABLE health_goals (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    goal_type VARCHAR(255) NOT NULL,
    target_value DOUBLE PRECISION NOT NULL,
    target_date DATE,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_goals_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_goals_user ON health_goals(user_id);
