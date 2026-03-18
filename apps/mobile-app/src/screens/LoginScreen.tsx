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
  const [showPassword, setShowPassword] = useState(false);
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
          {/* Logo and Header */}
          <View style={styles.header}>
            <View style={styles.logoCircle}>
              <Text style={styles.logoText}>H</Text>
            </View>
            <Text style={styles.title}>Health OS</Text>
            <Text style={styles.subtitle}>Your personal AI health coach</Text>
          </View>

          <View style={styles.authCard}>
            {/* Tab Switcher */}
            <View style={styles.tabContainer}>
              <TouchableOpacity
                style={[styles.tabBtn, tab === 'login' && styles.tabBtnActive]}
                onPress={() => setTab('login')}
              >
                <Text style={[styles.tabText, tab === 'login' && styles.tabTextActive]}>Log In</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.tabBtn, tab === 'register' && styles.tabBtnActive]}
                onPress={() => setTab('register')}
              >
                <Text style={[styles.tabText, tab === 'register' && styles.tabTextActive]}>Create Account</Text>
              </TouchableOpacity>
            </View>

            {/* Form */}
            <View style={styles.formGroup}>
              <Text style={styles.label}>Email</Text>
              <TextInput
                style={styles.input}
                value={email}
                onChangeText={setEmail}
                placeholder="name@example.com"
                placeholderTextColor="#9CA3AF80"
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
              />
            </View>

            <View style={styles.formGroup}>
              <View style={styles.passwordHeader}>
                <Text style={styles.label}>Password</Text>
                {tab === 'login' && (
                  <TouchableOpacity>
                    <Text style={styles.forgotText}>Forgot?</Text>
                  </TouchableOpacity>
                )}
              </View>
              <View style={styles.passwordInputContainer}>
                <TextInput
                  style={[styles.input, styles.passwordInput]}
                  value={password}
                  onChangeText={setPassword}
                  placeholder="••••••••"
                  placeholderTextColor="#9CA3AF80"
                  secureTextEntry={!showPassword}
                  returnKeyType="done"
                  onSubmitEditing={handleSubmit}
                />
                <TouchableOpacity
                  style={styles.eyeBtn}
                  onPress={() => setShowPassword(!showPassword)}
                >
                  <Text style={styles.eyeText}>
                    {showPassword ? '👁️' : '👁️‍🗨️'}
                  </Text>
                </TouchableOpacity>
              </View>
            </View>

            {/* Primary CTA */}
            <TouchableOpacity
              style={[styles.submitBtn, isLoading && styles.submitBtnDisabled]}
              onPress={handleSubmit}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <View style={styles.submitBtnContent}>
                  <Text style={styles.submitBtnText}>
                    {tab === 'login' ? 'Log In' : 'Create Account'}
                  </Text>
                  <Text style={styles.submitBtnIcon}>→</Text>
                </View>
              )}
            </TouchableOpacity>

            {/* Divider */}
            <View style={styles.dividerContainer}>
              <View style={styles.dividerLine} />
              <View style={styles.dividerTextContainer}>
                <Text style={styles.dividerText}>OR CONTINUE WITH</Text>
              </View>
            </View>

            {/* Social Logins */}
            <TouchableOpacity style={styles.socialBtn}>
              <Text style={styles.socialBtnIcon}>G</Text>
              <Text style={styles.socialBtnText}>Google</Text>
            </TouchableOpacity>
          </View>

          {/* Footer */}
          <Text style={styles.footerText}>
            By continuing, you agree to our{' '}
            <Text style={styles.footerLink}>Terms of Service</Text>
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#0A0A0A' },
  flex: { flex: 1 },
  inner: { flex: 1, paddingHorizontal: 16, justifyContent: 'center', width: '100%', maxWidth: 448, alignSelf: 'center' },
  header: { alignItems: 'center', marginBottom: 32 },
  logoCircle: { width: 72, height: 72, borderRadius: 36, backgroundColor: '#2463eb', alignItems: 'center', justifyContent: 'center', marginBottom: 24, shadowColor: '#2463eb', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 8, elevation: 4 },
  logoText: { color: '#FFFFFF', fontSize: 36, fontWeight: '700' },
  title: { color: '#FFFFFF', fontSize: 30, fontWeight: '700', letterSpacing: -0.5, marginBottom: 8 },
  subtitle: { color: '#9CA3AF', fontSize: 16 },
  authCard: { gap: 24 },
  tabContainer: { flexDirection: 'row', backgroundColor: '#141414', borderRadius: 12, padding: 4, borderWidth: 1, borderColor: '#1F2937' },
  tabBtn: { flex: 1, paddingVertical: 10, alignItems: 'center', borderRadius: 8 },
  tabBtnActive: { backgroundColor: '#2463eb', shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.1, shadowRadius: 2, elevation: 1 },
  tabText: { color: '#9CA3AF', fontSize: 14, fontWeight: '500' },
  tabTextActive: { color: '#FFFFFF' },
  formGroup: { gap: 6 },
  label: { color: '#9CA3AF', fontSize: 14, fontWeight: '500', paddingHorizontal: 4 },
  passwordHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 4 },
  forgotText: { color: '#2463eb', fontSize: 12 },
  input: { height: 56, backgroundColor: '#141414', borderWidth: 1, borderColor: '#1F2937', borderRadius: 12, paddingHorizontal: 16, color: '#F1F5F9', fontSize: 16 },
  passwordInputContainer: { flexDirection: 'row', alignItems: 'center' },
  passwordInput: { flex: 1 },
  eyeBtn: { position: 'absolute', right: 16, padding: 4 },
  eyeText: { fontSize: 16, color: '#9CA3AF' },
  submitBtn: { height: 56, backgroundColor: '#2463eb', borderRadius: 12, justifyContent: 'center', alignItems: 'center', marginTop: 16, shadowColor: '#2463eb', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.1, shadowRadius: 8, elevation: 4 },
  submitBtnDisabled: { opacity: 0.7 },
  submitBtnContent: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  submitBtnText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  submitBtnIcon: { color: '#FFFFFF', fontSize: 20, fontWeight: '600' },
  dividerContainer: { position: 'relative', paddingVertical: 8 },
  dividerLine: { position: 'absolute', top: '50%', left: 0, right: 0, borderTopWidth: 1, borderTopColor: '#1F2937' },
  dividerTextContainer: { flexDirection: 'row', justifyContent: 'center' },
  dividerText: { backgroundColor: '#0A0A0A', paddingHorizontal: 16, color: '#9CA3AF', fontSize: 12, fontWeight: '500', letterSpacing: 1 },
  socialBtn: { height: 56, backgroundColor: '#141414', borderWidth: 1, borderColor: '#1F2937', borderRadius: 12, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12 },
  socialBtnIcon: { fontSize: 18, color: '#4285F4', fontWeight: 'bold' },
  socialBtnText: { color: '#F1F5F9', fontSize: 14, fontWeight: '500' },
  footerText: { textAlign: 'center', color: '#9CA3AF', fontSize: 14, marginTop: 32 },
  footerLink: { color: '#CBD5E1', textDecorationLine: 'underline' },
});

