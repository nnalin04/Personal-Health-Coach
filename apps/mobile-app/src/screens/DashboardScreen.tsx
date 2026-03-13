/**
 * Page 2 — The Dashboard
 *
 * Read-only unified view with:
 *   - Action Ring: progress toward daily calorie/macro/step goals
 *   - AI Insight Card: personalized RAG-generated suggestion
 *   - Quick Stats: calories, protein, steps, water
 *   - FAB (+) → OmniChat
 *
 * Pulls from local WatermelonDB (offline-first, no re-fetch on every render).
 */
import React from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';

type Props = { navigation: StackNavigationProp<RootStackParamList, 'Dashboard'> };

// Placeholder stats — will be replaced by WatermelonDB queries
const MOCK_STATS = {
  calories:     { current: 1340, goal: 2000 },
  protein:      { current: 68,   goal: 120 },
  steps:        { current: 6200, goal: 10000 },
  water:        { current: 1.8,  goal: 2.5 },
};

const MOCK_INSIGHT = "Your iron intake has been below 60% RDA for 5 days. Try adding palak dal or til chutney to your meals — both are rich in iron and pair well with your Maharashtrian cuisine preference.";

function ActionRing({ label, current, goal, unit, color }: { label: string; current: number; goal: number; unit: string; color: string }) {
  const pct = Math.min(current / goal, 1);
  return (
    <View style={styles.ringCard}>
      <View style={[styles.ringOuter, { borderColor: color }]}>
        <View style={[styles.ringFill, { height: `${pct * 100}%` as any, backgroundColor: color + '33' }]} />
        <Text style={[styles.ringValue, { color }]}>{current}</Text>
        <Text style={styles.ringUnit}>{unit}</Text>
      </View>
      <Text style={styles.ringLabel}>{label}</Text>
    </View>
  );
}

export default function DashboardScreen({ navigation }: Props) {
  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.greeting}>Good morning</Text>
          <Text style={styles.date}>{new Date().toLocaleDateString('en-IN', { weekday: 'long', month: 'long', day: 'numeric' })}</Text>
        </View>

        {/* Action Rings */}
        <Text style={styles.sectionTitle}>Today's Progress</Text>
        <View style={styles.rings}>
          <ActionRing label="Calories"  current={MOCK_STATS.calories.current} goal={MOCK_STATS.calories.goal} unit="kcal" color="#F59E0B" />
          <ActionRing label="Protein"   current={MOCK_STATS.protein.current}  goal={MOCK_STATS.protein.goal}  unit="g"    color="#10B981" />
          <ActionRing label="Steps"     current={MOCK_STATS.steps.current}    goal={MOCK_STATS.steps.goal}    unit="steps" color="#3B82F6" />
          <ActionRing label="Water"     current={MOCK_STATS.water.current}    goal={MOCK_STATS.water.goal}    unit="L"    color="#06B6D4" />
        </View>

        {/* AI Insight */}
        <Text style={styles.sectionTitle}>Health OS Insight</Text>
        <View style={styles.insightCard}>
          <Text style={styles.insightIcon}>💡</Text>
          <Text style={styles.insightText}>{MOCK_INSIGHT}</Text>
        </View>

        {/* Quick stats */}
        <Text style={styles.sectionTitle}>This Week</Text>
        <View style={styles.statsRow}>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>5 / 7</Text>
            <Text style={styles.statLabel}>Days logged</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>1,720</Text>
            <Text style={styles.statLabel}>Avg calories</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statValue}>7,400</Text>
            <Text style={styles.statLabel}>Avg steps</Text>
          </View>
        </View>
      </ScrollView>

      {/* FAB → OmniChat */}
      <TouchableOpacity style={styles.fab} onPress={() => navigation.navigate('OmniChat')}>
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:          { flex: 1, backgroundColor: '#0A0A0A' },
  scroll:        { padding: 20, paddingBottom: 100 },
  header:        { marginBottom: 28 },
  greeting:      { fontSize: 26, fontWeight: '700', color: '#FFFFFF' },
  date:          { fontSize: 14, color: '#6B7280', marginTop: 4 },
  sectionTitle:  { fontSize: 13, fontWeight: '600', color: '#6B7280', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 14, marginTop: 8 },
  rings:         { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 28 },
  ringCard:      { alignItems: 'center', flex: 1 },
  ringOuter:     { width: 68, height: 68, borderRadius: 34, borderWidth: 3, alignItems: 'center', justifyContent: 'center', overflow: 'hidden', backgroundColor: '#1C1C1E', marginBottom: 8 },
  ringFill:      { position: 'absolute', bottom: 0, left: 0, right: 0 },
  ringValue:     { fontSize: 14, fontWeight: '700' },
  ringUnit:      { fontSize: 9, color: '#9CA3AF' },
  ringLabel:     { fontSize: 11, color: '#9CA3AF' },
  insightCard:   { backgroundColor: '#1C1C1E', borderRadius: 16, padding: 16, flexDirection: 'row', marginBottom: 28 },
  insightIcon:   { fontSize: 22, marginRight: 12, marginTop: 2 },
  insightText:   { flex: 1, fontSize: 14, color: '#D1D5DB', lineHeight: 22 },
  statsRow:      { flexDirection: 'row', gap: 12 },
  statBox:       { flex: 1, backgroundColor: '#1C1C1E', borderRadius: 12, padding: 14 },
  statValue:     { fontSize: 20, fontWeight: '700', color: '#FFFFFF' },
  statLabel:     { fontSize: 11, color: '#6B7280', marginTop: 4 },
  fab:           { position: 'absolute', bottom: 32, right: 24, width: 60, height: 60, borderRadius: 30, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', elevation: 8, shadowColor: '#2563EB', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.5, shadowRadius: 8 },
  fabText:       { color: '#FFFFFF', fontSize: 32, lineHeight: 36, fontWeight: '300' },
});
