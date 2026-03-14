/**
 * Shared axios instance used by all screens.
 *
 * - Automatically attaches `Authorization: Bearer <token>` from SecureStore.
 * - On 401, clears stored credentials (token is expired/revoked).
 * - Base URL read from EXPO_PUBLIC_API_URL env var; falls back to prod domain.
 */
import axios from 'axios';
import * as SecureStore from 'expo-secure-store';

export const BASE_URL =
  process.env.EXPO_PUBLIC_API_URL ?? 'https://healthcoach.duckdns.org/api';

const apiClient = axios.create({
  baseURL: BASE_URL,
  timeout: 20000,
  headers: { 'Content-Type': 'application/json' },
});

// Inject JWT before every request
apiClient.interceptors.request.use(async (config) => {
  const token = await SecureStore.getItemAsync('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// On 401 clear stored creds so the app re-prompts login
apiClient.interceptors.response.use(
  (res) => res,
  async (err) => {
    if (err.response?.status === 401) {
      await SecureStore.deleteItemAsync('auth_token');
      await SecureStore.deleteItemAsync('auth_user');
    }
    return Promise.reject(err);
  },
);

export default apiClient;
