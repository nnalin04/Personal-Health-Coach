/**
 * useTaskWebSocket — STOMP over WebSocket hook for real-time task notifications.
 *
 * Connects to the Spring Boot WebSocket endpoint and subscribes to the
 * user-specific topic /topic/tasks/{userId}.
 *
 * When a task completes, the AI Engine publishes to RabbitMQ task.completed →
 * Spring Boot TaskCompletionListener → WebSocket → this hook's onMessage callback.
 *
 * Usage:
 *   const { isConnected } = useTaskWebSocket(userId, (msg) => handleResult(msg));
 *
 * Falls back gracefully (returns isConnected=false) if:
 *   - @stomp/stompjs not available
 *   - Server not reachable within 5s
 *   - userId is empty/null
 */
import { useEffect, useRef, useState } from 'react';
import { BASE_URL } from '../services/apiClient';

export interface TaskCompletionMessage {
  taskId:  string;
  userId:  string;
  status:  'COMPLETED' | 'FAILED' | 'PARTIAL';
  result?: {
    type?:      string;
    message?:   string;
    mealLog?:   Record<string, unknown>;
    sources?:   string[];
    [key: string]: unknown;
  };
}

// Derive ws(s):// URL from the API base URL
function toWsUrl(apiUrl: string): string {
  return apiUrl
    .replace(/\/api$/, '')
    .replace(/^http/, 'ws') + '/ws';
}

export function useTaskWebSocket(
  userId: string | null | undefined,
  onMessage: (msg: TaskCompletionMessage) => void,
) {
  const [isConnected, setIsConnected] = useState(false);
  const clientRef = useRef<unknown>(null);

  useEffect(() => {
    if (!userId) return;

    let active = true;

    async function connect() {
      try {
        // Dynamic import so the app works even if @stomp/stompjs is absent
        const { Client } = await import('@stomp/stompjs');
        const wsUrl = toWsUrl(BASE_URL);

        const client = new Client({
          brokerURL:        wsUrl,
          reconnectDelay:   5000,
          heartbeatIncoming: 10000,
          heartbeatOutgoing: 10000,
          onConnect: () => {
            if (!active) return;
            setIsConnected(true);

            client.subscribe(`/topic/tasks/${userId}`, (frame) => {
              try {
                const msg: TaskCompletionMessage = JSON.parse(frame.body);
                onMessage(msg);
              } catch {
                // malformed frame — ignore
              }
            });
          },
          onDisconnect:     () => active && setIsConnected(false),
          onStompError:     (err) => console.warn('[WS] STOMP error:', err.headers?.message),
          onWebSocketError: (err) => console.warn('[WS] connection error:', err),
        });

        clientRef.current = client;
        client.activate();
      } catch (e) {
        console.warn('[WS] @stomp/stompjs not available — polling only:', e);
      }
    }

    connect();

    return () => {
      active = false;
      const c = clientRef.current as { deactivate?: () => void } | null;
      c?.deactivate?.();
      setIsConnected(false);
    };
  }, [userId]);

  return { isConnected };
}
