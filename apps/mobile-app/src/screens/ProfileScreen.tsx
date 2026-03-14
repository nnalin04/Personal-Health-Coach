/**
 * Profile Screen
 *
 * Accessible via avatar icon in Dashboard top-left.
 * Sections:
 *   1. Personal Info   — name, DOB, gender, weight, height
 *   2. Taste Profile   — region, cuisine style, dietary restrictions, health goal
 *   3. Payment         — plan, billing (placeholder for premium tier)
 *   4. Account         — export data, delete account, logout
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  SafeAreaView,
  Alert,
  Switch,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';

type Props = { navigation: StackNavigationProp<RootStackParamList, 'Profile'> };

interface ProfileData {
  // Personal
  name:          string;
  dob:           string;   // YYYY-MM-DD
  gender:        string;
  weightKg:      string;
  heightCm:      string;
  // Taste Profile
  region:        string;
  cuisineStyle:  string;
  restrictions:  string;
  healthGoal:    string;
  // Preferences
  notifications: boolean;
}

const INITIAL: ProfileData = {
  name:          'Your Name',
  dob:           '',
  gender:        '',
  weightKg:      '',
  heightCm:      '',
  region:        '',
  cuisineStyle:  '',
  restrictions:  'none',
  healthGoal:    '',
  notifications: true,
};

const GENDER_OPTIONS   = ['Male', 'Female', 'Other', 'Prefer not to say'];
const CUISINE_OPTIONS  = ['Vegetarian', 'Non-vegetarian', 'Vegan', 'Jain', 'Eggetarian'];
const GOAL_OPTIONS     = ['Lose weight', 'Build muscle', 'Manage diabetes', 'Improve fitness', 'Maintain weight'];

function SectionTitle({ title }: { title: string }) {
  return <Text style={styles.sectionTitle}>{title.toUpperCase()}</Text>;
}

function Field({
  label, value, onChangeText, placeholder, keyboardType = 'default',
}: {
  label: string; value: string; onChangeText: (t: string) => void;
  placeholder?: string; keyboardType?: 'default' | 'numeric' | 'decimal-pad';
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        style={styles.fieldInput}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder ?? label}
        placeholderTextColor="#555"
        keyboardType={keyboardType}
        returnKeyType="done"
      />
    </View>
  );
}

function ChipRow({
  label, options, selected, onSelect,
}: {
  label: string; options: string[]; selected: string; onSelect: (v: string) => void;
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.chipScroll}>
        {options.map((opt) => (
          <TouchableOpacity
            key={opt}
            style={[styles.chip, selected === opt && styles.chipSelected]}
            onPress={() => onSelect(opt)}
          >
            <Text style={[styles.chipText, selected === opt && styles.chipTextSelected]}>{opt}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

export default function ProfileScreen({ navigation }: Props) {
  const [profile, setProfile] = useState<ProfileData>(INITIAL);
  const [saved, setSaved] = useState(false);

  const set = (key: keyof ProfileData) => (val: string | boolean) =>
    setProfile((p) => ({ ...p, [key]: val }));

  const handleSave = () => {
    // TODO: PATCH /api/v1/profile with profile data
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const handleLogout = () => {
    Alert.alert('Log out', 'Are you sure you want to log out?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Log out', style: 'destructive', onPress: () => navigation.replace('Onboarding') },
    ]);
  };

  const handleExport = () => {
    Alert.alert('Export Data', 'Your data export will be emailed to you within 24 hours. (DPDP Act §17)');
    // TODO: POST /api/users/me/export
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Account',
      'This permanently deletes all your health data and cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete permanently',
          style: 'destructive',
          onPress: () => {
            // TODO: DELETE /api/users/me
            navigation.replace('Onboarding');
          },
        },
      ],
    );
  };

  // Initials avatar from name
  const initials = profile.name
    .split(' ')
    .map((w) => w[0] ?? '')
    .slice(0, 2)
    .join('')
    .toUpperCase() || '?';

  return (
    <SafeAreaView style={styles.safe}>
      {/* Top bar */}
      <View style={styles.topBar}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>← Dashboard</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Profile</Text>
        <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
          <Text style={styles.saveBtnText}>{saved ? '✓ Saved' : 'Save'}</Text>
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        {/* Avatar */}
        <View style={styles.avatarSection}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{initials}</Text>
          </View>
          <Text style={styles.avatarName}>{profile.name || 'Your Name'}</Text>
          <Text style={styles.avatarPlan}>Free Plan</Text>
        </View>

        {/* ── Personal Info ── */}
        <SectionTitle title="Personal Info" />
        <Field label="Full Name"     value={profile.name}     onChangeText={set('name')}     placeholder="e.g. Nishit Srivastava" />
        <Field label="Date of Birth" value={profile.dob}      onChangeText={set('dob')}      placeholder="YYYY-MM-DD" />
        <ChipRow label="Gender" options={GENDER_OPTIONS} selected={profile.gender} onSelect={set('gender') as (v: string) => void} />
        <View style={styles.row}>
          <View style={styles.halfField}>
            <Text style={styles.fieldLabel}>Weight (kg)</Text>
            <TextInput
              style={styles.fieldInput}
              value={profile.weightKg}
              onChangeText={set('weightKg')}
              placeholder="70"
              placeholderTextColor="#555"
              keyboardType="decimal-pad"
            />
          </View>
          <View style={[styles.halfField, { marginLeft: 12 }]}>
            <Text style={styles.fieldLabel}>Height (cm)</Text>
            <TextInput
              style={styles.fieldInput}
              value={profile.heightCm}
              onChangeText={set('heightCm')}
              placeholder="175"
              placeholderTextColor="#555"
              keyboardType="decimal-pad"
            />
          </View>
        </View>

        {/* ── Taste Profile ── */}
        <SectionTitle title="Food Preferences" />
        <Field label="Region / State" value={profile.region}      onChangeText={set('region')}      placeholder="e.g. Maharashtra, Punjab" />
        <ChipRow label="Cuisine Style"      options={CUISINE_OPTIONS} selected={profile.cuisineStyle}  onSelect={set('cuisineStyle') as (v: string) => void} />
        <Field label="Dietary Restrictions" value={profile.restrictions} onChangeText={set('restrictions')} placeholder="e.g. no onion-garlic, gluten-free, none" />
        <ChipRow label="Health Goal"        options={GOAL_OPTIONS}    selected={profile.healthGoal}    onSelect={set('healthGoal') as (v: string) => void} />

        {/* ── Notifications ── */}
        <SectionTitle title="Preferences" />
        <View style={styles.toggleRow}>
          <Text style={styles.fieldLabel}>Daily health summary notification</Text>
          <Switch
            value={profile.notifications}
            onValueChange={set('notifications') as (v: boolean) => void}
            trackColor={{ false: '#333', true: '#2563EB' }}
            thumbColor="#FFFFFF"
          />
        </View>

        {/* ── Payment ── */}
        <SectionTitle title="Plan & Payment" />
        <View style={styles.planCard}>
          <View>
            <Text style={styles.planName}>Free Plan</Text>
            <Text style={styles.planDesc}>Unlimited food + workout logging, AI macro estimation</Text>
          </View>
          <TouchableOpacity style={styles.upgradeBtn} onPress={() => Alert.alert('Coming soon', 'Premium plan with RAG insights and medical report OCR coming in a future release.')}>
            <Text style={styles.upgradeBtnText}>Upgrade</Text>
          </TouchableOpacity>
        </View>
        <View style={[styles.planCard, { opacity: 0.5 }]}>
          <View>
            <Text style={styles.planName}>Premium — ₹299/month</Text>
            <Text style={styles.planDesc}>+ RAG-powered insights, medical OCR, blood marker tracking</Text>
          </View>
        </View>

        {/* ── Account ── */}
        <SectionTitle title="Account" />
        <TouchableOpacity style={styles.accountRow} onPress={handleExport}>
          <Text style={styles.accountRowText}>📤  Export my data (DPDP Act)</Text>
          <Text style={styles.accountRowArrow}>›</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.accountRow} onPress={handleLogout}>
          <Text style={styles.accountRowText}>🔓  Log out</Text>
          <Text style={styles.accountRowArrow}>›</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.accountRow, styles.dangerRow]} onPress={handleDelete}>
          <Text style={[styles.accountRowText, styles.dangerText]}>🗑  Delete account & all data</Text>
          <Text style={styles.accountRowArrow}>›</Text>
        </TouchableOpacity>

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:              { flex: 1, backgroundColor: '#0A0A0A' },
  topBar:            { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#1C1C1E' },
  backBtn:           { width: 100 },
  backText:          { color: '#2563EB', fontSize: 15 },
  title:             { color: '#FFFFFF', fontSize: 17, fontWeight: '600' },
  saveBtn:           { width: 100, alignItems: 'flex-end' },
  saveBtnText:       { color: '#2563EB', fontSize: 15, fontWeight: '600' },
  scroll:            { padding: 20 },
  avatarSection:     { alignItems: 'center', marginBottom: 32 },
  avatar:            { width: 80, height: 80, borderRadius: 40, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', marginBottom: 12 },
  avatarText:        { color: '#FFFFFF', fontSize: 28, fontWeight: '700' },
  avatarName:        { color: '#FFFFFF', fontSize: 20, fontWeight: '600' },
  avatarPlan:        { color: '#6B7280', fontSize: 13, marginTop: 4 },
  sectionTitle:      { fontSize: 11, fontWeight: '700', color: '#6B7280', letterSpacing: 1.2, marginBottom: 12, marginTop: 24 },
  field:             { marginBottom: 16 },
  fieldLabel:        { fontSize: 13, color: '#9CA3AF', marginBottom: 6 },
  fieldInput:        { backgroundColor: '#1C1C1E', color: '#FFFFFF', borderRadius: 10, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15 },
  row:               { flexDirection: 'row', marginBottom: 16 },
  halfField:         { flex: 1 },
  chipScroll:        { marginTop: 4 },
  chip:              { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, backgroundColor: '#1C1C1E', marginRight: 8, borderWidth: 1, borderColor: '#333' },
  chipSelected:      { backgroundColor: '#1D4ED8', borderColor: '#2563EB' },
  chipText:          { color: '#9CA3AF', fontSize: 13 },
  chipTextSelected:  { color: '#FFFFFF', fontWeight: '600' },
  toggleRow:         { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#1C1C1E', borderRadius: 10, paddingHorizontal: 14, paddingVertical: 14, marginBottom: 16 },
  planCard:          { backgroundColor: '#1C1C1E', borderRadius: 12, padding: 16, marginBottom: 12, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  planName:          { color: '#FFFFFF', fontSize: 15, fontWeight: '600', marginBottom: 4 },
  planDesc:          { color: '#6B7280', fontSize: 12, maxWidth: 220 },
  upgradeBtn:        { backgroundColor: '#2563EB', paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20 },
  upgradeBtnText:    { color: '#FFFFFF', fontSize: 13, fontWeight: '600' },
  accountRow:        { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#1C1C1E', borderRadius: 10, paddingHorizontal: 16, paddingVertical: 16, marginBottom: 10 },
  accountRowText:    { color: '#E5E7EB', fontSize: 15 },
  accountRowArrow:   { color: '#6B7280', fontSize: 20 },
  dangerRow:         { backgroundColor: '#1C0A0A' },
  dangerText:        { color: '#EF4444' },
});
