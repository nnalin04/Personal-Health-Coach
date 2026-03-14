package com.healthcoach.config;

import com.healthcoach.security.JwtTokenProvider;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * WebSocket / STOMP channel-level security.
 *
 * Intercepts two STOMP commands:
 *
 *   CONNECT  — validates the JWT in the native Authorization header.
 *              Sets the STOMP session principal to the userId string
 *              so downstream checks can use accessor.getUser().
 *
 *   SUBSCRIBE — enforces topic ownership:
 *              /topic/tasks/{userId} may only be subscribed to by the
 *              user whose ID is encoded in the JWT supplied at CONNECT.
 *
 * Any other command (SEND, DISCONNECT, etc.) is passed through unchanged.
 */
@Configuration
public class WebSocketSecurityConfig implements WebSocketMessageBrokerConfigurer {

    private static final String TOPIC_TASKS_PREFIX = "/topic/tasks/";

    private final JwtTokenProvider jwtTokenProvider;

    public WebSocketSecurityConfig(JwtTokenProvider jwtTokenProvider) {
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {

            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor =
                        MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) return message;

                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    String authHeader = accessor.getFirstNativeHeader("Authorization");
                    if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                        throw new AccessDeniedException("Missing Authorization header in STOMP CONNECT");
                    }
                    String token = authHeader.substring(7);
                    if (!jwtTokenProvider.validateToken(token)) {
                        throw new AccessDeniedException("Invalid or expired JWT in STOMP CONNECT");
                    }
                    Long userId = jwtTokenProvider.getUserIdFromToken(token);
                    // Persist principal across the STOMP session
                    final String userIdStr = userId.toString();
                    accessor.setUser(() -> userIdStr);
                }

                if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
                    var principal = accessor.getUser();
                    if (principal == null) {
                        throw new AccessDeniedException("STOMP session has no authenticated principal");
                    }
                    String destination = accessor.getDestination();
                    if (destination != null && destination.startsWith(TOPIC_TASKS_PREFIX)) {
                        String topicUserId = destination.substring(TOPIC_TASKS_PREFIX.length());
                        if (!topicUserId.equals(principal.getName())) {
                            throw new AccessDeniedException(
                                "Forbidden: cannot subscribe to topic of another user");
                        }
                    }
                }

                return message;
            }
        });
    }
}
