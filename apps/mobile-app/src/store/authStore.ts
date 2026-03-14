/**
 * Auth state — persisted in expo-secure-store across app restarts.
 *
 * Keys stored:
 *   auth_token    — JWT string
 *   auth_user     — JSON-serialised UserProfile
 *   onboarding_done — 'true' once taste-profile setup is complete
 */
import { create } from 'zustand';
import * as SecureStore from 'expo-secure-store';
import apiClient from '../services/apiClient';

export interface UserProfile {
  id: number;
  email: string;
  goal?: string | null;
  region?: string | null;
  cuisineStyle?: string | null;
  dietaryRestrictions?: string | null;
  gender?: string | null;
  age?: number | null;
  height?: number | null;
}

interface AuthState {
  token: string | null;
  user: UserProfile | null;
  isLoading: boolean;
  isInitialized: boolean;
  onboardingDone: boolean;

  /** Call once on app start — restores session from SecureStore. */
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  markOnboardingDone: () => Promise<void>;
  refreshUser: () => Promise<void>;
  logout: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: null,
  user: null,
  isLoading: false,
  isInitialized: false,
  onboardingDone: false,

  initialize: async () => {
    try {
      const [token, userJson, onboardingFlag] = await Promise.all([
        SecureStore.getItemAsync('auth_token'),
        SecureStore.getItemAsync('auth_user'),
        SecureStore.getItemAsync('onboarding_done'),
      ]);
      set({
        token: token ?? null,
        user: userJson ? JSON.parse(userJson) : null,
        onboardingDone: onboardingFlag === 'true',
        isInitialized: true,
      });
    } catch {
      set({ isInitialized: true });
    }
  },

  login: async (email, password) => {
    set({ isLoading: true });
    try {
      const res = await apiClient.post('/auth/login', { email, password });
      const { accessToken, user } = res.data;
      await SecureStore.setItemAsync('auth_token', accessToken);
      await SecureStore.setItemAsync('auth_user', JSON.stringify(user));
      set({ token: accessToken, user, isLoading: false });
    } catch (err: any) {
      set({ isLoading: false });
      throw new Error(err?.response?.data?.message ?? 'Login failed. Check your credentials.');
    }
  },

  register: async (email, password) => {
    set({ isLoading: true });
    try {
      const res = await apiClient.post('/auth/register', { email, password });
      const { accessToken, user } = res.data;
      await SecureStore.setItemAsync('auth_token', accessToken);
      await SecureStore.setItemAsync('auth_user', JSON.stringify(user));
      set({ token: accessToken, user, isLoading: false });
    } catch (err: any) {
      set({ isLoading: false });
      throw new Error(err?.response?.data?.message ?? 'Registration failed. Email may already be in use.');
    }
  },

  markOnboardingDone: async () => {
    await SecureStore.setItemAsync('onboarding_done', 'true');
    set({ onboardingDone: true });
  },

  refreshUser: async () => {
    try {
      const res = await apiClient.get('/users/me');
      const user = res.data;
      await SecureStore.setItemAsync('auth_user', JSON.stringify(user));
      set({ user });
    } catch {
      // silently skip if network unavailable
    }
  },

  logout: async () => {
    await Promise.all([
      SecureStore.deleteItemAsync('auth_token'),
      SecureStore.deleteItemAsync('auth_user'),
      SecureStore.deleteItemAsync('onboarding_done'),
    ]);
    set({ token: null, user: null, onboardingDone: false });
  },
}));
