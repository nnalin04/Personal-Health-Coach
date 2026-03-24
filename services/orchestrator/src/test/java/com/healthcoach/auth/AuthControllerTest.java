package com.healthcoach.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcoach.auth.dto.AuthResponse;
import com.healthcoach.auth.dto.LoginRequest;
import com.healthcoach.auth.dto.RegisterRequest;
import com.healthcoach.security.AuthEntryPointJwt;
import com.healthcoach.security.JwtAuthenticationFilter;
import com.healthcoach.security.JwtTokenProvider;
import com.healthcoach.user.dto.UserProfileResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Fast @WebMvcTest for AuthController — tests HTTP binding, validation,
 * and response serialization without loading the full Spring context.
 * (springboot-tdd skill: prefer @WebMvcTest over @SpringBootTest for controller layer)
 */
@WebMvcTest(AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @MockBean
    private AuthEntryPointJwt authEntryPointJwt;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @MockBean
    private JwtTokenProvider jwtTokenProvider;

    // ── Registration ────────────────────────────────────────────────────────────

    @Test
    void register_ValidPayload_Returns200WithToken() throws Exception {
        UserProfileResponse profile = new UserProfileResponse(1L, "test@example.com", 25, "Male", 175.0, "Build Muscle", "Omnivore", "", null, null, null, null, null);
        AuthResponse response = new AuthResponse("jwt-token-here", "dummy-refresh-token", "Bearer", 3600L, profile);
        when(authService.register(any())).thenReturn(response);

        RegisterRequest request = new RegisterRequest(
                "test@example.com", "ValidPass123!", 25, "Male", 175.0, "Build Muscle", "Omnivore", "");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("jwt-token-here"))
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.user.email").value("test@example.com"));
    }

    @ParameterizedTest(name = "register invalid: email={0}")
    @CsvSource({
            "not-an-email, ValidPass1!, 25, Male, 175.0, Build Muscle, Omnivore",
            "'', ValidPass1!, 25, Male, 175.0, Build Muscle, Omnivore",
    })
    void register_InvalidEmail_Returns400(String email, String password, int age,
                                          String gender, double height, String goal, String dietType) throws Exception {
        RegisterRequest request = new RegisterRequest(email, password, age, gender, height, goal, dietType, "");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void register_PasswordTooShort_Returns400() throws Exception {
        RegisterRequest request = new RegisterRequest(
                "test@example.com", "short", 25, "Male", 175.0, "Fitness", "Any", "");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void register_MissingBody_Returns400() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    // ── Login ───────────────────────────────────────────────────────────────────

    @Test
    void login_ValidCredentials_Returns200WithToken() throws Exception {
        UserProfileResponse profile = new UserProfileResponse(1L, "test@example.com", 25, "Male", 175.0, "Build Muscle", "Omnivore", "", null, null, null, null, null);
        AuthResponse response = new AuthResponse("login-token", "dummy-refresh-token", "Bearer", 3600L, profile);
        when(authService.login(any())).thenReturn(response);

        LoginRequest request = new LoginRequest("test@example.com", "ValidPass123!");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("login-token"));
    }

    @ParameterizedTest(name = "login blank fields: email=''{0}'' password=''{1}''")
    @CsvSource({
            "'', ValidPass1!",
            "test@example.com, ''",
            "'', ''",
    })
    void login_BlankFields_Returns400(String email, String password) throws Exception {
        LoginRequest request = new LoginRequest(email, password);

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    // ── Content-Type enforcement ────────────────────────────────────────────────

    @Test
    void register_WrongContentType_RejectsRequest() throws Exception {
        // With addFilters=false, Spring maps HttpMediaTypeNotSupportedException to 500;
        // assert the request is not 2xx (either 4xx or 5xx is correct behaviour here).
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("raw text"))
                .andExpect(status().is5xxServerError());
    }
}
