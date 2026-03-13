package com.healthcoach.goals;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.healthcoach.user.User;
import jakarta.persistence.*;
import java.time.LocalDate;

@Entity
@Table(name = "health_goals", indexes = {
        @Index(name = "idx_health_goals_user_id", columnList = "user_id"),
        @Index(name = "idx_health_goals_user_completed", columnList = "user_id,completed")
})
public class HealthGoal {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String goalType; // WEIGHT, STEPS, CALORIES, PROTEIN, WORKOUTS_PER_WEEK

    @Column(nullable = false)
    private Double targetValue;

    private LocalDate targetDate;

    private boolean completed = false;

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public String getGoalType() { return goalType; }
    public void setGoalType(String goalType) { this.goalType = goalType; }
    public Double getTargetValue() { return targetValue; }
    public void setTargetValue(Double targetValue) { this.targetValue = targetValue; }
    public LocalDate getTargetDate() { return targetDate; }
    public void setTargetDate(LocalDate targetDate) { this.targetDate = targetDate; }
    public boolean isCompleted() { return completed; }
    public void setCompleted(boolean completed) { this.completed = completed; }
}
