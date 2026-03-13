package com.healthcoach.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import java.security.Key;
import java.util.Date;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class JwtTokenProvider {

    private final Key signingKey;
    private final long jwtExpirationMs;

    public JwtTokenProvider(
            @Value("${app.jwt.secret}") String jwtSecret,
            @Value("${app.jwt.expiration-ms}") long jwtExpirationMs
    ) {
        byte[] keyBytes = Decoders.BASE64.decode(padBase64(jwtSecret));
        this.signingKey = Keys.hmacShaKeyFor(keyBytes);
        this.jwtExpirationMs = jwtExpirationMs;
    }

    public String generateToken(UserPrincipal principal) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + jwtExpirationMs);

        return Jwts.builder()
                .subject(principal.getUsername())
                .claim("uid", principal.getId())
                .claim("role", principal.getRole().name())
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(signingKey)
                .compact();
    }

    public Long getUserIdFromToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(Keys.hmacShaKeyFor(signingKey.getEncoded()))
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return claims.get("uid", Long.class);
    }

    public boolean validateToken(String authToken) {
        try {
            Jwts.parser().verifyWith(Keys.hmacShaKeyFor(signingKey.getEncoded())).build().parseSignedClaims(authToken);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    private String padBase64(String rawSecret) {
        // Accept regular text secrets by converting to base64 if needed.
        String candidate = rawSecret.trim();
        if (!candidate.matches("^[A-Za-z0-9+/=]+$") || candidate.length() % 4 != 0) {
            return java.util.Base64.getEncoder().encodeToString(candidate.getBytes());
        }
        return candidate;
    }
}
