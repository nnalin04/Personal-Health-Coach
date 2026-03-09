package com.healthcoach.user;

import com.healthcoach.security.UserPrincipal;
import com.healthcoach.user.dto.UpdateProfileRequest;
import com.healthcoach.user.dto.UserDataExportDto;
import com.healthcoach.user.dto.UserProfileResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/me")
    public UserProfileResponse getMe(@AuthenticationPrincipal UserPrincipal principal) {
        return UserProfileResponse.from(userService.getById(principal.getId()));
    }

    @PutMapping("/me")
    public UserProfileResponse updateMe(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        return UserProfileResponse.from(userService.updateProfile(principal.getId(), request));
    }

    /** Export all user data as JSON (GDPR compliance). */
    @GetMapping("/me/export")
    public UserDataExportDto exportMyData(@AuthenticationPrincipal UserPrincipal principal) {
        return userService.exportData(principal.getId());
    }

    /** Permanently delete the authenticated user and all their data. Returns 204 No Content. */
    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteMyAccount(@AuthenticationPrincipal UserPrincipal principal) {
        userService.deleteAccount(principal.getId());
        return ResponseEntity.noContent().build();
    }
}
