package com.healthcoach.auth;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.healthcoach.auth.dto.AuthResponse;
import com.healthcoach.auth.dto.LoginRequest;
import com.healthcoach.auth.dto.RegisterRequest;
import com.healthcoach.security.JwtTokenProvider;
import com.healthcoach.user.User;
import com.healthcoach.user.UserRepository;
import com.healthcoach.user.UserRole;
import com.healthcoach.auth.RefreshTokenService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private AuthenticationManager authenticationManager;
    @Mock
    private JwtTokenProvider jwtTokenProvider;
    @Mock
    private RefreshTokenService refreshTokenService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, authenticationManager, jwtTokenProvider, refreshTokenService);
    }

    @Test
    void register_Success() {
        RegisterRequest request = new RegisterRequest("test@example.com", "password", 25, "Male", 180.0, "Weight Loss",
                "None", null);
        when(userRepository.existsByEmail(any())).thenReturn(false);
        when(passwordEncoder.encode(any())).thenReturn("encodedPassword");
        when(userRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
        when(jwtTokenProvider.generateToken(any())).thenReturn("testToken");

        AuthResponse response = authService.register(request);

        assertNotNull(response);
        assertEquals("testToken", response.accessToken());
        verify(userRepository).save(any(User.class));
    }

    @Test
    void register_EmailAlreadyExists_ThrowsException() {
        RegisterRequest request = new RegisterRequest("test@example.com", "password", 25, "Male", 180.0, "Weight Loss",
                "None", null);
        when(userRepository.existsByEmail(any())).thenReturn(true);

        assertThrows(RuntimeException.class, () -> authService.register(request));
    }
}
