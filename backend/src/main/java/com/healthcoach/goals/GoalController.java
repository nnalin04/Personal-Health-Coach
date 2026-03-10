package com.healthcoach.goals;

import com.healthcoach.goals.dto.CreateGoalRequest;
import com.healthcoach.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/goals")
public class GoalController {
    private final GoalService goalService;

    public GoalController(GoalService goalService) {
        this.goalService = goalService;
    }

    @GetMapping
    public List<HealthGoal> getMyGoals(@AuthenticationPrincipal UserPrincipal userPrincipal) {
        return goalService.getUserGoals(userPrincipal.getId());
    }

    @PostMapping
    public HealthGoal createGoal(@AuthenticationPrincipal UserPrincipal userPrincipal,
                                 @Valid @RequestBody CreateGoalRequest request) {
        return goalService.createGoal(userPrincipal.getId(), request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteGoal(
            @AuthenticationPrincipal UserPrincipal userPrincipal,
            @PathVariable Long id
    ) {
        goalService.deleteGoal(userPrincipal.getId(), id);
        return ResponseEntity.ok().build();
    }
}
