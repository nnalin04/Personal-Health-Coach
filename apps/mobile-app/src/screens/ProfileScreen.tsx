import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  SafeAreaView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { AppStackParamList } from '../navigation/AppNavigator';
import { useAuthStore } from '../store/authStore';
import apiClient from '../services/apiClient';
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';

type Props = { navigation: StackNavigationProp<AppStackParamList, 'Profile'> };

interface UserData {
  name?:            string;
  email:            string;
  age?:             number | null;
  gender?:          string;
  heightCm?:        number | null;
  weightKg?:        number | null;
  activityLevel?:   string;
  dietaryPreference?: string;
  medicalConditions?: string[];
  goal?:            string;
  region?:          string;
}

export default function ProfileScreen({ navigation }: Props) {
  const { user, token, logout, updateToken, updateUser } = useAuthStore();
  const [profile, setProfile] = useState<UserData>({ email: user?.email ?? '' });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);

  useEffect(() => {
    async function loadProfile() {
      try {
        const res = await apiClient.get('/users/me');
        if (res.data) setProfile({ ...res.data, email: res.data.email ?? user?.email ?? '' });
      } catch {
        // Fallback to minimal info if fetch fails
      } finally {
        setLoading(false);
      }
    }
    loadProfile();
  }, [user]);

  const handleChange = (field: keyof UserData, value: string) => {
    setProfile((prev) => ({ ...prev, [field]: value }));
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const payload = {
        name: profile.name,
        age: profile.age ? Number(profile.age) : null,
        gender: profile.gender,
        heightCm: profile.heightCm ? Number(profile.heightCm) : null,
        weightKg: profile.weightKg ? Number(profile.weightKg) : null,
        activityLevel: profile.activityLevel,
        dietaryPreference: profile.dietaryPreference,
        medicalConditions: profile.medicalConditions,
        goal: profile.goal,
        region: profile.region,
      };

      const res = await apiClient.put('/users/me', payload);
      // update local Zustand state so the app knows the new profile
      const updatedUser = { ...user, ...res.data };
      updateUser(updatedUser);

      // if JWT token needs refresh (some backends issue new JWT on profile update)
      if (res.headers['x-new-token']) {
        updateToken(res.headers['x-new-token']);
      }

      Alert.alert('Success', 'Profile updated successfully.');
    } catch (err: any) {
      Alert.alert('Error', err.response?.data?.error || 'Failed to update profile.');
    } finally {
      setSaving(false);
    }
  };

  const handleLogout = () => {
    logout();
    // In a typical React Navigation setup with separate Auth/App stacks based on token presence,
    // logging out (clearing the token) automatically unmounts the App stack and mounts the Auth stack.
    // So we don't need to manually navigate to 'Login' here if it's not in the AppStackParamList.
  };

  const initials = profile.email ? profile.email.split('@')[0].slice(0, 2).toUpperCase() : 'NA';
  const displayName = profile.name || (profile.email ? profile.email.split('@')[0] : 'User');

  if (loading) {
    return (
      <SafeAreaView style={styles.safeCentered}>
        <ActivityIndicator color="#2463eb" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safe}>
      {/* TopAppBar */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
            <MaterialIcons name="arrow-back" size={24} color="#9CA3AF" />
          </TouchableOpacity>
        </View>
        <Text style={styles.headerTitle}>Profile</Text>
        <View style={styles.headerRight}>
          <TouchableOpacity onPress={handleSave} disabled={saving}>
            {saving ? (
              <ActivityIndicator size="small" color="#2463eb" />
            ) : (
              <Text style={styles.saveText}>Save</Text>
            )}
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Profile Card */}
        <View style={styles.profileCard}>
          <View style={styles.profileHeader}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{initials}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.profileName}>{displayName}</Text>
              <Text style={styles.profileEmail}>{profile.email}</Text>
            </View>
            <TouchableOpacity style={styles.editBtn}>
              <Text style={styles.editBtnText}>Edit Photo</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Form Sections */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Personal Details</Text>
          
          <View style={styles.inputGroup}>
            <View style={styles.inputIconWrapper}>
              <MaterialIcons name="person" size={20} color="#9CA3AF" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.inputLabel}>Full Name</Text>
              <TextInput
                style={styles.input}
                value={profile.name || ''}
                onChangeText={(t) => handleChange('name', t)}
                placeholder="Not set"
                placeholderTextColor="#6B7280"
              />
            </View>
          </View>

          <View style={{ flexDirection: 'row', gap: 16 }}>
            <View style={[styles.inputGroup, { flex: 1 }]}>
              <View style={styles.inputIconWrapper}>
                <MaterialIcons name="cake" size={20} color="#9CA3AF" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.inputLabel}>Age</Text>
                <TextInput
                  style={styles.input}
                  value={profile.age ? String(profile.age) : ''}
                  onChangeText={(t) => handleChange('age', t)}
                  keyboardType="numeric"
                  placeholder="Not set"
                  placeholderTextColor="#6B7280"
                />
              </View>
            </View>
            <View style={[styles.inputGroup, { flex: 1 }]}>
              <View style={styles.inputIconWrapper}>
                <MaterialIcons name="wc" size={20} color="#9CA3AF" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.inputLabel}>Gender</Text>
                <TextInput
                  style={styles.input}
                  value={profile.gender || ''}
                  onChangeText={(t) => handleChange('gender', t)}
                  placeholder="Not set"
                  placeholderTextColor="#6B7280"
                />
              </View>
            </View>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Body Metrics</Text>
          
          <View style={{ flexDirection: 'row', gap: 16 }}>
            <View style={[styles.inputGroup, { flex: 1 }]}>
              <View style={styles.inputIconWrapper}>
                <MaterialIcons name="height" size={20} color="#9CA3AF" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.inputLabel}>Height (cm)</Text>
                <TextInput
                  style={styles.input}
                  value={profile.heightCm ? String(profile.heightCm) : ''}
                  onChangeText={(t) => handleChange('heightCm', t)}
                  keyboardType="numeric"
                  placeholder="Not set"
                  placeholderTextColor="#6B7280"
                />
              </View>
            </View>
            <View style={[styles.inputGroup, { flex: 1 }]}>
              <View style={styles.inputIconWrapper}>
                <MaterialIcons name="monitor-weight" size={20} color="#9CA3AF" />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.inputLabel}>Weight (kg)</Text>
                <TextInput
                  style={styles.input}
                  value={profile.weightKg ? String(profile.weightKg) : ''}
                  onChangeText={(t) => handleChange('weightKg', t)}
                  keyboardType="numeric"
                  placeholder="Not set"
                  placeholderTextColor="#6B7280"
                />
              </View>
            </View>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Preferences</Text>
          
          <View style={styles.inputGroup}>
            <View style={styles.inputIconWrapper}>
              <MaterialIcons name="directions-run" size={20} color="#9CA3AF" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.inputLabel}>Activity Level</Text>
              <TextInput
                style={styles.input}
                value={profile.activityLevel || ''}
                onChangeText={(t) => handleChange('activityLevel', t)}
                placeholder="Sedentary, Active..."
                placeholderTextColor="#6B7280"
              />
            </View>
          </View>

          <View style={styles.inputGroup}>
            <View style={styles.inputIconWrapper}>
              <MaterialIcons name="restaurant-menu" size={20} color="#9CA3AF" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.inputLabel}>Dietary Preference</Text>
              <TextInput
                style={styles.input}
                value={profile.dietaryPreference || ''}
                onChangeText={(t) => handleChange('dietaryPreference', t)}
                placeholder="Vegetarian, Keto..."
                placeholderTextColor="#6B7280"
              />
            </View>
          </View>

          <View style={styles.inputGroup}>
            <View style={styles.inputIconWrapper}>
              <MaterialIcons name="flag" size={20} color="#9CA3AF" />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.inputLabel}>Region</Text>
              <TextInput
                style={styles.input}
                value={profile.region || ''}
                onChangeText={(t) => handleChange('region', t)}
                placeholder="For local food reco..."
                placeholderTextColor="#6B7280"
              />
            </View>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account</Text>
          
          <TouchableOpacity style={styles.actionRow} onPress={handleLogout}>
            <View style={styles.actionIconWrapper}>
              <MaterialIcons name="logout" size={20} color="#EF4444" />
            </View>
            <Text style={styles.actionTextLogout}>Log Out</Text>
            <MaterialIcons name="chevron-right" size={24} color="#374151" />
          </TouchableOpacity>
        </View>

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeCentered: { flex: 1, backgroundColor: '#0A0A0A', justifyContent: 'center', alignItems: 'center' },
  safe: { flex: 1, backgroundColor: '#0A0A0A' },
  header: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#0A0A0A', borderBottomWidth: 1, borderBottomColor: '#1F2937', padding: 16 },
  headerLeft: { flex: 1, flexDirection: 'row', alignItems: 'center' },
  backBtn: { padding: 4 },
  headerTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '700', textAlign: 'center' },
  headerRight: { flex: 1, alignItems: 'flex-end', justifyContent: 'center' },
  saveText: { color: '#2463eb', fontSize: 16, fontWeight: '600' },
  scroll: { padding: 24, paddingBottom: 60, gap: 32 },
  profileCard: { backgroundColor: '#141414', borderRadius: 16, padding: 20, borderWidth: 1, borderColor: 'rgba(255, 255, 255, 0.05)' },
  profileHeader: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  avatar: { width: 64, height: 64, borderRadius: 32, backgroundColor: 'rgba(36, 99, 235, 0.2)', borderWidth: 1, borderColor: 'rgba(36, 99, 235, 0.3)', alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: '#2463eb', fontSize: 24, fontWeight: '700' },
  profileName: { color: '#FFFFFF', fontSize: 20, fontWeight: '700', marginBottom: 4 },
  profileEmail: { color: '#9CA3AF', fontSize: 14 },
  editBtn: { paddingHorizontal: 16, paddingVertical: 8, backgroundColor: '#1C1C1E', borderRadius: 8, borderWidth: 1, borderColor: '#374151' },
  editBtnText: { color: '#FFFFFF', fontSize: 12, fontWeight: '500' },
  section: { gap: 12 },
  sectionTitle: { color: '#6B7280', fontSize: 12, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4, marginLeft: 4 },
  inputGroup: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#141414', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255, 255, 255, 0.05)', paddingHorizontal: 16, paddingVertical: 12, gap: 16 },
  inputIconWrapper: { width: 32, alignItems: 'center' },
  inputLabel: { color: '#6B7280', fontSize: 12, fontWeight: '500', marginBottom: 2 },
  input: { color: '#FFFFFF', fontSize: 15, padding: 0, fontWeight: '500' },
  actionRow: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#141414', borderRadius: 12, borderWidth: 1, borderColor: 'rgba(255, 255, 255, 0.05)', paddingHorizontal: 16, paddingVertical: 16, gap: 16 },
  actionIconWrapper: { width: 32, alignItems: 'center' },
  actionTextLogout: { flex: 1, color: '#EF4444', fontSize: 16, fontWeight: '500' },
});
