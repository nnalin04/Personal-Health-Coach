package com.healthcoach.user;

import com.healthcoach.common.ResourceNotFoundException;
import com.healthcoach.user.dto.UpdateProfileRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User getById(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
    }

    @Transactional
    public User updateProfile(Long userId, UpdateProfileRequest request) {
        User user = getById(userId);
        if (request.age() != null) user.setAge(request.age());
        if (request.gender() != null) user.setGender(request.gender());
        if (request.height() != null) user.setHeight(request.height());
        if (request.goal() != null) user.setGoal(request.goal());
        if (request.dietType() != null) user.setDietType(request.dietType());
        if (request.medicalFlags() != null) user.setMedicalFlags(request.medicalFlags());
        if (request.region() != null) user.setRegion(request.region());
        if (request.cuisineStyle() != null) user.setCuisineStyle(request.cuisineStyle());
        if (request.dietaryRestrictions() != null) user.setDietaryRestrictions(request.dietaryRestrictions());
        return userRepository.save(user);
    }
}
