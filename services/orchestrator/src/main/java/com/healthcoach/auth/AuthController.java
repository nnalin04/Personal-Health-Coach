package com.healthcoach.auth;

import com.healthcoach.auth.dto.AuthResponse;
import com.healthcoach.auth.dto.GoogleLoginRequest;
import com.healthcoach.auth.dto.LoginRequest;
import com.healthcoach.auth.dto.RefreshRequest;
import com.healthcoach.auth.dto.RegisterRequest;
import com.healthcoach.security.UserPrincipal;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/google")
    public AuthResponse googleLogin(@Valid @RequestBody GoogleLoginRequest request) {
        return authService.googleLogin(request);
    }

    /**
     * Exchange an expiring refresh token for a fresh access + refresh token pair.
     * The old refresh token is revoked on use (token-family rotation).
     * Public endpoint — no JWT required (the refresh token itself is the credential).
     */
    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request);
    }

    /**
     * Revoke all refresh tokens for the authenticated user (logout from all devices).
     * The client should discard its stored access and refresh tokens after calling this.
     */
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@AuthenticationPrincipal UserPrincipal principal) {
        authService.logout(principal.getId());
        return ResponseEntity.noContent().build();
    }
}
