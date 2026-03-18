package com.healthcoach.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * Sets a correlation ID on every inbound request so that all log lines
 * within the same request share a common {@code correlationId} field.
 *
 * Strategy:
 *  1. Read {@code X-Correlation-ID} from the request header (mobile/gateway may pre-set it).
 *  2. If absent, generate a new UUID.
 *  3. Put it into SLF4J MDC — Logback's LogstashEncoder (prod) and the dev pattern
 *     both pick it up automatically.
 *  4. Echo it back in the response as {@code X-Correlation-ID} so clients can
 *     correlate their traces with server logs.
 *  5. Always clear MDC after the request to prevent thread-pool leakage.
 */
public class CorrelationIdFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Correlation-ID";
    public static final String MDC_KEY = "correlationId";

    @Override
    protected void doFilterInternal(
            HttpServletRequest  request,
            HttpServletResponse response,
            FilterChain         filterChain
    ) throws ServletException, IOException {
        String correlationId = request.getHeader(HEADER);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }
        MDC.put(MDC_KEY, correlationId);
        response.setHeader(HEADER, correlationId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);   // always clear — Tomcat reuses threads
        }
    }
}
