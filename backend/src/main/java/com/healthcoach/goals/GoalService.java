package com.healthcoach.goals;

import com.healthcoach.common.ResourceNotFoundException;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GoalService {
    private final HealthGoalRepository goalRepository;
    private final UserService userService;

    public GoalService(HealthGoalRepository goalRepository, UserService userService) {
        this.goalRepository = goalRepository;
        this.userService = userService;
    }

    public List<HealthGoal> getUserGoals(Long userId) {
        return goalRepository.findByUserId(userId);
    }

    @Transactional
    public HealthGoal createGoal(Long userId, HealthGoal goal) {
        User user = userService.getById(userId);
        goal.setUser(user);
        return goalRepository.save(goal);
    }

    @Transactional
    public void deleteGoal(Long userId, Long goalId) {
        HealthGoal goal = goalRepository.findByIdAndUserId(goalId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Goal not found: " + goalId));
        goalRepository.delete(goal);
    }
}
