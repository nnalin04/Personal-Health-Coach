/**
 * Page 2 — The Dashboard
 *
 * Live data from the backend via apiClient (JWT-authenticated):
 *   GET /api/health-summary/me?window=7  → AI insight text
 *   GET /api/food/logs                   → today's calories + protein
 *   GET /api/steps                       → today's steps
 *   GET /api/body-metrics                → latest weight
 *
 * Falls back to zeros gracefully — the user is prompted to log via OmniChat.
 */
import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { AppStackParamList } from '../navigation/AppNavigator';
import { useAuthStore } from '../store/authStore';
import apiClient from '../services/apiClient';

type Props = { navigation: StackNavigationProp<AppStackParamList, 'Dashboard'> };

interface DashStats {
  caloriesKcal: number;
  proteinG:     number;
  stepsCount:   number;
  weightKg:     number | null;
}

const CALORIE_GOAL = 2000;
const PROTEIN_GOAL = 120;
const STEPS_GOAL   = 10000;

function ActionRing({ label, current, goal, unit, color }: {
  label: string; current: number; goal: number; unit: string; color: string;
}) {
  const pct = Math.min(current / Math.max(goal, 1), 1);
  return (
    <View style={styles.ringCard}>
      <View style={[styles.ringOuter, { borderColor: color }]}>
        <View style={[styles.ringFill, { height: `${pct * 100}%` as any, backgroundColor: color + '33' }]} />
        <Text style={[styles.ringValue, { color }]}>{current.toLocaleString()}</Text>
        <Text style={styles.ringUnit}>{unit}</Text>
      </View>
      <Text style={styles.ringLabel}>{label}</Text>
    </View>
  );
}

export default function DashboardScreen({ navigation }: Props) {
  const { user, logout } = useAuthStore();
  const [stats, setStats]     = useState<DashStats>({ caloriesKcal: 0, proteinG: 0, stepsCount: 0, weightKg: null });
  const [insight, setInsight] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  const fetchData = useCallback(async () => {
    try {
      const [foodRes, stepsRes, metricsRes, summaryRes] = await Promise.allSettled([
        apiClient.get('/food/logs', { params: { date: today, size: 100 } }),
        apiClient.get('/steps',     { params: { date: today } }),
        apiClient.get('/body-metrics', { params: { size: 1 } }),
        apiClient.get('/health-summary/me', { params: { window: 7 } }),
      ]);

      // Aggregate today's food logs
      let caloriesKcal = 0, proteinG = 0;
      if (foodRes.status === 'fulfilled') {
        const logs: any[] = foodRes.value.data?.content ?? foodRes.value.data ?? [];
        logs.forEach((l: any) => {
          caloriesKcal += Number(l.calories  ?? l.calorie ?? 0);
          proteinG     += Number(l.protein   ?? l.proteinG ?? 0);
        });
      }

      // Today's steps
      let stepsCount = 0;
      if (stepsRes.status === 'fulfilled') {
        const s = stepsRes.value.data;
        const list: any[] = Array.isArray(s) ? s : s?.content ?? (s ? [s] : []);
        const todayEntry = list.find((x: any) => x.date === today);
        stepsCount = todayEntry?.stepCount ?? todayEntry?.steps ?? (list[0]?.stepCount ?? 0);
      }

      // Latest weight
      let weightKg: number | null = null;
      if (metricsRes.status === 'fulfilled') {
        const m = metricsRes.value.data;
        const list: any[] = Array.isArray(m) ? m : m?.content ?? (m ? [m] : []);
        weightKg = list[0]?.weight ?? null;
      }

      // AI insight
      if (summaryRes.status === 'fulfilled') {
        const d = summaryRes.value.data;
        const lines: string[] = d?.recommendations ?? d?.insights ?? d?.suggestions ?? [];
        if (lines.length > 0) setInsight(lines[0]);
      }

      setStats({ caloriesKcal: Math.round(caloriesKcal), proteinG: Math.round(proteinG), stepsCount, weightKg });
    } catch {
      // silently degrade
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [today]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const onRefresh = () => { setRefreshing(true); fetchData(); };

  // Avatar initials from email
  const initials = user?.email
    ? user.email.split('@')[0].slice(0, 2).toUpperCase()
    : '?';

  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  })();

  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#2563EB" />}
      >
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.headerRow}>
            <View>
              <Text style={styles.greeting}>{greeting}</Text>
              <Text style={styles.date}>
                {new Date().toLocaleDateString('en-IN', { weekday: 'long', month: 'long', day: 'numeric' })}
              </Text>
            </View>
            <TouchableOpacity style={styles.avatarBtn} onPress={() => navigation.navigate('Profile')}>
              <Text style={styles.avatarInitials}>{initials}</Text>
            </TouchableOpacity>
          </View>
        </View>

        {loading ? (
          <ActivityIndicator color="#2563EB" style={{ marginTop: 40 }} />
        ) : (
          <>
            {/* Action Rings */}
            <Text style={styles.sectionTitle}>Today's Progress</Text>
            <View style={styles.rings}>
              <ActionRing label="Calories" current={stats.caloriesKcal} goal={CALORIE_GOAL} unit="kcal" color="#F59E0B" />
              <ActionRing label="Protein"  current={stats.proteinG}     goal={PROTEIN_GOAL} unit="g"    color="#10B981" />
              <ActionRing label="Steps"    current={stats.stepsCount}   goal={STEPS_GOAL}   unit="steps" color="#3B82F6" />
              {stats.weightKg != null && (
                <ActionRing label="Weight" current={stats.weightKg}     goal={stats.weightKg} unit="kg" color="#A855F7" />
              )}
            </View>

            {/* AI Insight */}
            <Text style={styles.sectionTitle}>Health OS Insight</Text>
            <View style={styles.insightCard}>
              <Text style={styles.insightIcon}>💡</Text>
              <Text style={styles.insightText}>
                {insight || 'Log your meals and workouts to unlock personalised AI insights.'}
              </Text>
            </View>

            {/* Empty state CTA */}
            {stats.caloriesKcal === 0 && (
              <TouchableOpacity
                style={styles.ctaCard}
                onPress={() => navigation.navigate('OmniChat')}
              >
                <Text style={styles.ctaTitle}>Log your first meal</Text>
                <Text style={styles.ctaText}>
                  Tap + to describe what you ate or upload a food photo — AI estimates calories and nutrients instantly.
                </Text>
              </TouchableOpacity>
            )}
          </>
        )}
      </ScrollView>

      {/* FAB → OmniChat */}
      <TouchableOpacity style={styles.fab} onPress={() => navigation.navigate('OmniChat')}>
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:           { flex: 1, backgroundColor: '#0A0A0A' },
  scroll:         { padding: 20, paddingBottom: 100 },
  header:         { marginBottom: 28 },
  headerRow:      { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  greeting:       { fontSize: 26, fontWeight: '700', color: '#FFFFFF' },
  date:           { fontSize: 14, color: '#6B7280', marginTop: 4 },
  avatarBtn:      { width: 44, height: 44, borderRadius: 22, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center' },
  avatarInitials: { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  sectionTitle:   { fontSize: 13, fontWeight: '600', color: '#6B7280', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 14, marginTop: 8 },
  rings:          { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 28, flexWrap: 'wrap', gap: 8 },
  ringCard:       { alignItems: 'center', minWidth: 70 },
  ringOuter:      { width: 68, height: 68, borderRadius: 34, borderWidth: 3, alignItems: 'center', justifyContent: 'center', overflow: 'hidden', backgroundColor: '#1C1C1E', marginBottom: 8 },
  ringFill:       { position: 'absolute', bottom: 0, left: 0, right: 0 },
  ringValue:      { fontSize: 13, fontWeight: '700' },
  ringUnit:       { fontSize: 9, color: '#9CA3AF' },
  ringLabel:      { fontSize: 11, color: '#9CA3AF' },
  insightCard:    { backgroundColor: '#1C1C1E', borderRadius: 16, padding: 16, flexDirection: 'row', marginBottom: 28 },
  insightIcon:    { fontSize: 22, marginRight: 12, marginTop: 2 },
  insightText:    { flex: 1, fontSize: 14, color: '#D1D5DB', lineHeight: 22 },
  ctaCard:        { backgroundColor: '#1D4ED8' + '22', borderRadius: 16, padding: 20, borderWidth: 1, borderColor: '#2563EB' + '66', marginBottom: 20 },
  ctaTitle:       { color: '#60A5FA', fontSize: 16, fontWeight: '700', marginBottom: 8 },
  ctaText:        { color: '#93C5FD', fontSize: 14, lineHeight: 21 },
  fab:            { position: 'absolute', bottom: 32, right: 24, width: 60, height: 60, borderRadius: 30, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', elevation: 8, shadowColor: '#2563EB', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.5, shadowRadius: 8 },
  fabText:        { color: '#FFFFFF', fontSize: 32, lineHeight: 36, fontWeight: '300' },
});
