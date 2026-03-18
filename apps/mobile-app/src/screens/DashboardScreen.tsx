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
import Svg, { Circle } from 'react-native-svg';
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';

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

function ActionRing({ label, current, goal, unit, color, isDashed = false, icon }: {
  label: string; current: number; goal: number; unit: string; color: string; isDashed?: boolean; icon?: string
}) {
  const pct = Math.min(current / Math.max(goal, 1), 1);
  const radius = 40;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - pct * circumference;

  return (
    <View style={styles.glassCard}>
      <View style={{ alignItems: 'center', justifyContent: 'center', position: 'relative', width: 96, height: 96, marginBottom: 12 }}>
        <Svg width="96" height="96" viewBox="0 0 96 96" style={{ transform: [{ rotate: '-90deg' }] }}>
          <Circle
            cx="48"
            cy="48"
            r={radius}
            stroke="rgba(255, 255, 255, 0.05)"
            strokeWidth="8"
            fill="transparent"
            strokeDasharray={isDashed ? "4 4" : undefined}
          />
          <Circle
            cx="48"
            cy="48"
            r={radius}
            stroke={color}
            strokeWidth="8"
            fill="transparent"
            strokeDasharray={circumference}
            strokeDashoffset={isDashed ? circumference : strokeDashoffset}
            strokeLinecap={isDashed ? "square" : "round"}
          />
        </Svg>
        <View style={{ position: 'absolute', alignItems: 'center', justifyContent: 'center' }}>
          {icon ? (
            <MaterialIcons name={icon} size={24} color={color} />
          ) : (
            <Text style={{ fontSize: 12, fontWeight: '700', color: '#FFFFFF' }}>{Math.round(pct * 100)}%</Text>
          )}
        </View>
      </View>
      <View style={{ alignItems: 'center' }}>
        <Text style={{ fontSize: 12, color: '#6B7280', fontWeight: '500', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 4 }}>
          {label}
        </Text>
        <Text style={{ fontSize: 18, fontWeight: '700', color: '#FFFFFF' }}>
          {current.toLocaleString()} {unit}
        </Text>
      </View>
    </View>
  );
}

export default function DashboardScreen({ navigation }: Props) {
  const { user } = useAuthStore();
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
    : 'NA';
  
  const displayName = user?.email ? user.email.split('@')[0] : 'User';

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
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#2463eb" />}
      >
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>{greeting}, {displayName}</Text>
            <Text style={styles.date}>
              {new Date().toLocaleDateString('en-IN', { weekday: 'long', month: 'long', day: 'numeric' })}
            </Text>
          </View>
          <TouchableOpacity style={styles.avatarBtn} onPress={() => navigation.navigate('Profile')}>
            <Text style={styles.avatarInitials}>{initials}</Text>
          </TouchableOpacity>
        </View>

        {/* Quick Actions */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.quickActions} contentContainerStyle={{ gap: 12, paddingHorizontal: 24 }}>
          <TouchableOpacity style={styles.quickActionBtn} onPress={() => navigation.navigate('OmniChat')}>
            <MaterialIcons name="add-circle" size={18} color="#2463eb" />
            <Text style={styles.quickActionText}>Log meal</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.quickActionBtn} onPress={() => navigation.navigate('OmniChat')}>
            <MaterialIcons name="directions-walk" size={18} color="#2463eb" />
            <Text style={styles.quickActionText}>Log steps</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.quickActionBtn} onPress={() => navigation.navigate('OmniChat')}>
            <MaterialIcons name="upload-file" size={18} color="#2463eb" />
            <Text style={styles.quickActionText}>Upload report</Text>
          </TouchableOpacity>
        </ScrollView>

        {loading ? (
          <ActivityIndicator color="#2463eb" style={{ marginTop: 40 }} />
        ) : (
          <View style={{ paddingHorizontal: 24 }}>
            {/* Metric Grid */}
            <View style={styles.grid}>
              <ActionRing label="Calories" current={stats.caloriesKcal} goal={CALORIE_GOAL} unit="kcal" color="#F59E0B" />
              <ActionRing label="Protein"  current={stats.proteinG}     goal={PROTEIN_GOAL} unit="g"    color="#10B981" />
              <ActionRing label="Steps"    current={stats.stepsCount}   goal={STEPS_GOAL}   unit="steps" color="#3B82F6" />
              <ActionRing label="Weight" current={stats.weightKg || 0} goal={stats.weightKg || 1} unit="kg" color="#A855F7" isDashed icon="monitor-weight" />
            </View>

            {/* AI Insight */}
            <View style={{ marginTop: 24 }}>
              <View style={styles.insightCard}>
                <View style={styles.insightHeader}>
                  <MaterialIcons name="auto-awesome" size={18} color="#2463eb" style={{ marginRight: 8 }} />
                  <Text style={styles.insightTitle}>AI INSIGHT</Text>
                </View>
                <Text style={styles.insightText}>
                  {insight || 'Log your meals and workouts to unlock personalised AI insights.'}
                </Text>
              </View>
            </View>
          </View>
        )}
      </ScrollView>

      {/* Floating Action Button */}
      <TouchableOpacity style={styles.fab} onPress={() => navigation.navigate('OmniChat')}>
        <MaterialIcons name="add" size={32} color="#FFFFFF" />
      </TouchableOpacity>

      {/* Bottom Nav Bar */}
      <View style={styles.bottomNav}>
        <TouchableOpacity style={styles.navItem}>
          <MaterialIcons name="grid-view" size={24} color="#2463eb" />
          <Text style={[styles.navText, { color: '#2463eb' }]}>Dashboard</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem}>
          <MaterialIcons name="favorite" size={24} color="#6B7280" />
          <Text style={styles.navText}>Health</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem}>
          <MaterialIcons name="insights" size={24} color="#6B7280" />
          <Text style={styles.navText}>Insights</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem} onPress={() => navigation.navigate('Profile')}>
          <MaterialIcons name="person" size={24} color="#6B7280" />
          <Text style={styles.navText}>Profile</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#0A0A0A' },
  scroll: { paddingBottom: 120 },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: 24 },
  greeting: { fontSize: 22, fontWeight: '700', color: '#FFFFFF', lineHeight: 28 },
  date: { fontSize: 14, color: '#6B7280', marginTop: 2 },
  avatarBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(36, 99, 235, 0.2)', borderWidth: 1, borderColor: 'rgba(36, 99, 235, 0.3)', alignItems: 'center', justifyContent: 'center' },
  avatarInitials: { color: '#2463eb', fontSize: 14, fontWeight: '700' },
  quickActions: { marginBottom: 32 },
  quickActionBtn: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 16, backgroundColor: '#141414', borderRadius: 9999, borderWidth: 1, borderColor: 'rgba(255, 255, 255, 0.05)', gap: 8 },
  quickActionText: { color: '#FFFFFF', fontSize: 14, fontWeight: '500' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', gap: 16 },
  glassCard: { width: '47%', backgroundColor: '#141414', borderWidth: 1, borderColor: 'rgba(255, 255, 255, 0.05)', borderRadius: 16, padding: 20, alignItems: 'center' },
  insightCard: { backgroundColor: '#141414', borderLeftWidth: 4, borderLeftColor: '#2463eb', borderTopWidth: 1, borderTopColor: 'rgba(255, 255, 255, 0.05)', borderBottomWidth: 1, borderBottomColor: 'rgba(255, 255, 255, 0.05)', borderRightWidth: 1, borderRightColor: 'rgba(255, 255, 255, 0.05)', borderRadius: 16, borderTopLeftRadius: 0, borderBottomLeftRadius: 0, padding: 20 },
  insightHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  insightTitle: { fontSize: 10, fontWeight: '700', color: '#2463eb', textTransform: 'uppercase', letterSpacing: 1 },
  insightText: { fontSize: 14, color: '#CBD5E1', lineHeight: 22 },
  fab: { position: 'absolute', bottom: 96, right: 24, width: 56, height: 56, borderRadius: 28, backgroundColor: '#2463eb', alignItems: 'center', justifyContent: 'center', shadowColor: '#2463eb', shadowOffset: { width: 0, height: 0 }, shadowOpacity: 0.4, shadowRadius: 20, elevation: 8, zIndex: 50 },
  bottomNav: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: 'rgba(10, 10, 10, 0.8)', borderTopWidth: 1, borderTopColor: 'rgba(255, 255, 255, 0.05)', flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 24, paddingVertical: 12, paddingBottom: 24, zIndex: 40 },
  navItem: { alignItems: 'center', gap: 4 },
  navText: { fontSize: 10, fontWeight: '500', color: '#6B7280' }
});
