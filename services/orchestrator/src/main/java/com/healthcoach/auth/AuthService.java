package com.healthcoach.auth;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.healthcoach.auth.dto.AuthResponse;
import com.healthcoach.auth.dto.GoogleLoginRequest;
import com.healthcoach.auth.dto.LoginRequest;
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

    @Value("${google.client.id}")
    private String googleClientId;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtTokenProvider jwtTokenProvider) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtTokenProvider = jwtTokenProvider;
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
        UserPrincipal principal = UserPrincipal.from(savedUser);
        String token = jwtTokenProvider.generateToken(principal);

        return new AuthResponse(token, "Bearer", UserProfileResponse.from(savedUser));
    }

    public AuthResponse login(LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email().toLowerCase(), request.password()));

        UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
        String token = jwtTokenProvider.generateToken(principal);
        User user = userRepository.findById(principal.getId())
                .orElseThrow(() -> new BadRequestException("User account not found"));

        return new AuthResponse(token, "Bearer", UserProfileResponse.from(user));
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

        if (idToken == null) {
            throw new BadRequestException("Invalid Google ID Token");
        }

        GoogleIdToken.Payload payload = idToken.getPayload();
        String email = payload.getEmail();

        Optional<User> userOptional = userRepository.findByEmail(email.toLowerCase());
        User user;
        if (userOptional.isPresent()) {
            user = userOptional.get();
        } else {
            // Register new user via Google
            user = new User();
            user.setEmail(email.toLowerCase());
            user.setPassword(""); // No password for Google users
            user.setRole(UserRole.ROLE_USER);
            user = userRepository.save(user);
        }

        UserPrincipal principal = UserPrincipal.from(user);
        String token = jwtTokenProvider.generateToken(principal);

        return new AuthResponse(token, "Bearer", UserProfileResponse.from(user));
    }
}
