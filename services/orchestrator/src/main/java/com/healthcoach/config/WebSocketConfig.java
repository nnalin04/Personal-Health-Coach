package com.healthcoach.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * STOMP over WebSocket configuration.
 *
 * Endpoint: /ws  (native WebSocket — no SockJS, React Native compatible)
 *
 * Client connects to:  wss://healthcoach.duckdns.org/ws
 * Subscribe to topic:  /topic/tasks/{userId}   ← AI task completions
 *
 * Flow:
 *   AI Engine → RabbitMQ task.completed → TaskCompletionListener
 *             → SimpMessagingTemplate → /topic/tasks/{userId} → mobile
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // In-memory simple broker for /topic destinations
        config.enableSimpleBroker("/topic");
        // Prefix for messages routed to @MessageMapping methods (not used yet)
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Native WebSocket endpoint — no SockJS (React Native uses native WS)
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*");
        // SockJS fallback for browser-based clients (optional)
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}
