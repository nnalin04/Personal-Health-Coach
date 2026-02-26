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
        user.setAge(request.age());
        user.setGender(request.gender());
        user.setHeight(request.height());
        user.setGoal(request.goal());
        user.setDietType(request.dietType());
        user.setMedicalFlags(request.medicalFlags());
        return userRepository.save(user);
    }
}
