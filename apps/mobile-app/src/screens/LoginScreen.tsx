/**
 * Login / Register Screen
 *
 * Shown when the user has no stored JWT. Two tabs:
 *   - Log In  (email + password → POST /api/auth/login)
 *   - Sign Up (email + password → POST /api/auth/register)
 *
 * On success the authStore token is set → AppNavigator transitions
 * automatically to the Onboarding or Dashboard stack.
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { useAuthStore } from '../store/authStore';

export default function LoginScreen() {
  const [tab, setTab] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login, register, isLoading } = useAuthStore();

  const handleSubmit = async () => {
    const e = email.trim().toLowerCase();
    const p = password.trim();
    if (!e || !p) {
      Alert.alert('Missing fields', 'Please enter your email and password.');
      return;
    }
    if (p.length < 6) {
      Alert.alert('Password too short', 'Password must be at least 6 characters.');
      return;
    }
    try {
      if (tab === 'login') {
        await login(e, p);
      } else {
        await register(e, p);
      }
    } catch (err: any) {
      Alert.alert('Error', err.message ?? 'Something went wrong. Try again.');
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.inner}>
          {/* Logo / title */}
          <View style={styles.logoSection}>
            <View style={styles.logoCircle}>
              <Text style={styles.logoText}>H</Text>
            </View>
            <Text style={styles.appName}>Health OS</Text>
            <Text style={styles.tagline}>Your personal AI health intelligence</Text>
          </View>

          {/* Tab switcher */}
          <View style={styles.tabs}>
            <TouchableOpacity
              style={[styles.tab, tab === 'login' && styles.tabActive]}
              onPress={() => setTab('login')}
            >
              <Text style={[styles.tabText, tab === 'login' && styles.tabTextActive]}>Log In</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.tab, tab === 'register' && styles.tabActive]}
              onPress={() => setTab('register')}
            >
              <Text style={[styles.tabText, tab === 'register' && styles.tabTextActive]}>Create Account</Text>
            </TouchableOpacity>
          </View>

          {/* Form */}
          <View style={styles.form}>
            <Text style={styles.label}>Email</Text>
            <TextInput
              style={styles.input}
              value={email}
              onChangeText={setEmail}
              placeholder="you@example.com"
              placeholderTextColor="#555"
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
            />

            <Text style={styles.label}>Password</Text>
            <TextInput
              style={styles.input}
              value={password}
              onChangeText={setPassword}
              placeholder="••••••••"
              placeholderTextColor="#555"
              secureTextEntry
              returnKeyType="done"
              onSubmitEditing={handleSubmit}
            />

            <TouchableOpacity
              style={[styles.btn, isLoading && styles.btnDisabled]}
              onPress={handleSubmit}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.btnText}>
                  {tab === 'login' ? 'Log In' : 'Create Account'}
                </Text>
              )}
            </TouchableOpacity>
          </View>

          <Text style={styles.disclaimer}>
            By continuing you agree to our Terms of Service.{'\n'}
            Your health data stays private and is never sold.
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:              { flex: 1, backgroundColor: '#0A0A0A' },
  flex:              { flex: 1 },
  inner:             { flex: 1, paddingHorizontal: 28, justifyContent: 'center' },
  logoSection:       { alignItems: 'center', marginBottom: 40 },
  logoCircle:        { width: 72, height: 72, borderRadius: 36, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', marginBottom: 14 },
  logoText:          { color: '#FFFFFF', fontSize: 32, fontWeight: '800' },
  appName:           { color: '#FFFFFF', fontSize: 26, fontWeight: '700', marginBottom: 6 },
  tagline:           { color: '#6B7280', fontSize: 14, textAlign: 'center' },
  tabs:              { flexDirection: 'row', backgroundColor: '#1C1C1E', borderRadius: 12, padding: 4, marginBottom: 28 },
  tab:               { flex: 1, paddingVertical: 10, alignItems: 'center', borderRadius: 10 },
  tabActive:         { backgroundColor: '#2563EB' },
  tabText:           { color: '#6B7280', fontSize: 14, fontWeight: '600' },
  tabTextActive:     { color: '#FFFFFF' },
  form:              { gap: 8 },
  label:             { color: '#9CA3AF', fontSize: 13, marginBottom: 4, marginTop: 8 },
  input:             { backgroundColor: '#1C1C1E', color: '#FFFFFF', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 14, fontSize: 15 },
  btn:               { backgroundColor: '#2563EB', borderRadius: 14, paddingVertical: 16, alignItems: 'center', marginTop: 20 },
  btnDisabled:       { opacity: 0.6 },
  btnText:           { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  disclaimer:        { color: '#374151', fontSize: 12, textAlign: 'center', marginTop: 32, lineHeight: 18 },
});
