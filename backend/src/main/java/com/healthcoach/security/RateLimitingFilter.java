package com.healthcoach.security;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.web.filter.OncePerRequestFilter;

public class RateLimitingFilter extends OncePerRequestFilter {

    // Standard endpoints: 20 req/min per IP
    private static final int STANDARD_CAPACITY = 20;
    // AI-heavy endpoints (Gemini calls): 5 req/min per IP — protects API budget
    private static final int AI_CAPACITY = 5;

    // Paths that invoke Gemini and are expensive
    private static final Set<String> AI_PATHS = Set.of(
            "/api/health-summary/me/ai-insights",
            "/api/nutrient/recommendations",
            "/api/extract-metrics"
    );

    // Standard rate-limited paths
    private static final Set<String> STANDARD_PREFIXES = Set.of(
            "/api/auth",
            "/api/medical/reports"
    );

    private final Map<String, Bucket> standardBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> aiBuckets = new ConcurrentHashMap<>();

    private Bucket createBucket(int capacity) {
        Bandwidth limit = Bandwidth.classic(capacity, Refill.greedy(capacity, Duration.ofMinutes(1)));
        return Bucket.builder().addLimit(limit).build();
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String path = request.getRequestURI();
        String clientIp = getClientIP(request);

        if (AI_PATHS.contains(path)) {
            Bucket bucket = aiBuckets.computeIfAbsent(clientIp, k -> createBucket(AI_CAPACITY));
            if (!bucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.getWriter().write("Too many AI requests. Please wait before retrying.");
                return;
            }
        } else if (STANDARD_PREFIXES.stream().anyMatch(path::startsWith)) {
            Bucket bucket = standardBuckets.computeIfAbsent(clientIp, k -> createBucket(STANDARD_CAPACITY));
            if (!bucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.getWriter().write("Too many requests. Please try again later.");
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Resolve client IP. Trust X-Forwarded-For only when the direct connection comes
     * from a known internal proxy (nginx container on the Docker bridge network).
     * If the header is absent or the request arrives directly, use remoteAddr.
     */
    private String getClientIP(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();
        // Only trust X-Forwarded-For when the request arrives from localhost or Docker bridge
        boolean fromTrustedProxy = remoteAddr.equals("127.0.0.1")
                || remoteAddr.equals("::1")
                || remoteAddr.startsWith("172.");   // Docker default bridge subnet
        if (fromTrustedProxy) {
            String xfHeader = request.getHeader("X-Forwarded-For");
            if (xfHeader != null && !xfHeader.isBlank()) {
                return xfHeader.split(",")[0].trim();
            }
        }
        return remoteAddr;
    }
}
