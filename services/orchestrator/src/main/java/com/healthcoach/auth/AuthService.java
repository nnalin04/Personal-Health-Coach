package com.healthcoach.auth;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.healthcoach.auth.dto.AuthResponse;
import com.healthcoach.auth.dto.GoogleLoginRequest;
import com.healthcoach.auth.dto.LoginRequest;
import com.healthcoach.auth.dto.RefreshRequest;
import com.healthcoach.auth.dto.RegisterRequest;
import com.healthcoach.common.BadRequestException;
import com.healthcoach.security.JwtTokenProvider;
import com.healthcoach.security.UserPrincipal;
import com.healthcoach.user.User;
import com.healthcoach.user.UserRepository;
import com.healthcoach.user.UserRole;
import com.healthcoach.user.dto.UserProfileResponse;
import java.util.Collections;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final RefreshTokenService refreshTokenService;

    @Value("${google.client.id}")
    private String googleClientId;

    @Value("${app.jwt.expiration-ms:3600000}")
    private long accessExpirationMs;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtTokenProvider jwtTokenProvider,
            RefreshTokenService refreshTokenService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtTokenProvider = jwtTokenProvider;
        this.refreshTokenService = refreshTokenService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BadRequestException("Email already registered");
        }

        User user = new User();
        user.setEmail(request.email().toLowerCase());
        user.setPassword(passwordEncoder.encode(request.password()));
        user.setAge(request.age());
        user.setGender(request.gender());
        user.setHeight(request.height());
        user.setGoal(request.goal());
        user.setDietType(request.dietType());
        user.setMedicalFlags(request.medicalFlags());
        user.setRole(UserRole.ROLE_USER);

        User savedUser = userRepository.save(user);
        return buildAuthResponse(savedUser);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email().toLowerCase(), request.password()));

        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new BadRequestException("User account not found"));
        return buildAuthResponse(user);
    }

    @Transactional
    public AuthResponse googleLogin(GoogleLoginRequest request) {
        GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), new GsonFactory())
                .setAudience(Collections.singletonList(googleClientId))
                .build();

        GoogleIdToken idToken;
        try {
            idToken = verifier.verify(request.getIdToken());
        } catch (Exception e) {
            throw new BadRequestException("Invalid Google ID Token");
        }
        if (idToken == null) throw new BadRequestException("Invalid Google ID Token");

        String email = idToken.getPayload().getEmail();
        User user = userRepository.findByEmail(email.toLowerCase()).orElseGet(() -> {
            User u = new User();
            u.setEmail(email.toLowerCase());
            u.setPassword("");
            u.setRole(UserRole.ROLE_USER);
            return userRepository.save(u);
        });

        return buildAuthResponse(user);
    }

    /**
     * Exchange a valid refresh token for a new access + refresh token pair.
     * Old refresh token is revoked on use (rotation).
     */
    @Transactional
    public AuthResponse refresh(RefreshRequest request) {
        // Decode user from the refresh token without trusting it yet
        // We look up by hash, which validates authenticity implicitly
        String raw = request.refreshToken();
        // Find user via hash — RefreshTokenService validates expiry + revocation
        // We need user context: try to find token first to get user
        String hash = com.healthcoach.auth.RefreshTokenService.sha256Public(raw);
        RefreshToken stored = refreshTokenService.findByHash(hash)
                .orElseThrow(() -> new BadRequestException("Invalid refresh token"));

        User user = stored.getUser();
        refreshTokenService.validateAndRotate(raw, user); // revokes old token
        return buildAuthResponse(user);
    }

    /** Revoke all refresh tokens (logout from all devices). */
    @Transactional
    public void logout(Long userId) {
        refreshTokenService.revokeAll(userId);
    }

    // ── private helpers ────────────────────────────────────────────────────────

    private AuthResponse buildAuthResponse(User user) {
        UserPrincipal principal = UserPrincipal.from(user);
        String accessToken  = jwtTokenProvider.generateToken(principal);
        String refreshToken = refreshTokenService.createRefreshToken(user);
        return new AuthResponse(
                accessToken,
                refreshToken,
                "Bearer",
                accessExpirationMs / 1000,
                UserProfileResponse.from(user)
        );
    }
}
