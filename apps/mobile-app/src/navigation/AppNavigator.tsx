import React, { useEffect } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { useAuthStore } from '../store/authStore';

import LoginScreen      from '../screens/LoginScreen';
import OnboardingScreen from '../screens/OnboardingScreen';
import DashboardScreen  from '../screens/DashboardScreen';
import OmniChatScreen   from '../screens/OmniChatScreen';
import ProfileScreen    from '../screens/ProfileScreen';

// ── Type declarations ────────────────────────────────────────────────────────

export type AuthStackParamList = {
  Login: undefined;
};

export type AppStackParamList = {
  Onboarding: undefined;
  Dashboard:  undefined;
  OmniChat:   undefined;
  Profile:    undefined;
};

// Merged so existing screen Props still compile
export type RootStackParamList = AuthStackParamList & AppStackParamList;

// ── Stacks ───────────────────────────────────────────────────────────────────

const AuthStack = createStackNavigator<AuthStackParamList>();
const AppStack  = createStackNavigator<AppStackParamList>();

function AuthNavigator() {
  return (
    <AuthStack.Navigator screenOptions={{ headerShown: false }}>
      <AuthStack.Screen name="Login" component={LoginScreen} />
    </AuthStack.Navigator>
  );
}

function AppNavigatorInner() {
  const { onboardingDone } = useAuthStore();
  return (
    <AppStack.Navigator
      screenOptions={{ headerShown: false }}
      initialRouteName={onboardingDone ? 'Dashboard' : 'Onboarding'}
    >
      <AppStack.Screen name="Onboarding" component={OnboardingScreen} />
      <AppStack.Screen name="Dashboard"  component={DashboardScreen} />
      <AppStack.Screen name="OmniChat"   component={OmniChatScreen} />
      <AppStack.Screen name="Profile"    component={ProfileScreen} options={{ presentation: 'card' }} />
    </AppStack.Navigator>
  );
}

// ── Root ─────────────────────────────────────────────────────────────────────

export default function AppNavigator() {
  const { token, isInitialized, initialize } = useAuthStore();

  useEffect(() => {
    initialize();
  }, []);

  if (!isInitialized) {
    return (
      <View style={styles.splash}>
        <ActivityIndicator size="large" color="#2563EB" />
      </View>
    );
  }

  return (
    <NavigationContainer>
      {token ? <AppNavigatorInner /> : <AuthNavigator />}
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  splash: { flex: 1, backgroundColor: '#0A0A0A', alignItems: 'center', justifyContent: 'center' },
});
