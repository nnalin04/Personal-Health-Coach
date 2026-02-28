import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

class LoggingScreen extends ConsumerStatefulWidget {
  const LoggingScreen({super.key});

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/health-summary/me');
      setState(() {
        _summary = Map<String, dynamic>.from(res.data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Activity Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Workouts'),
            Tab(text: 'Nutrition'),
            Tab(text: 'Metrics'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _WorkoutsTab(summary: _summary),
                _NutritionTab(summary: _summary),
                _MetricsTab(summary: _summary),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _WorkoutsTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Activities",
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(DateTime.now()),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorkoutItem(
          title: 'Upper Body Power',
          subtitle: '60 min • Strength',
          trailing: '420 kcal',
          icon: Icons.fitness_center_rounded,
        ),
        const SizedBox(height: 12),
        _WorkoutItem(
          title: 'Steady State Cardio',
          subtitle: '30 min • Zone 2',
          trailing: '280 kcal',
          icon: Icons.directions_run_rounded,
        ),
      ],
    );
  }
}

class _WorkoutItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;

  const _WorkoutItem({required this.title, required this.subtitle, required this.trailing, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E262C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262F36)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(trailing, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _NutritionTab extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _NutritionTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "Nutrient Breakdown",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E262C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF262F36)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1,840',
                        style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white),
                      ),
                      Text(
                        'kcal consumed today',
                        style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Goal: 2,200',
                      style: GoogleFonts.inter(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _MacroItem(label: 'Protein', value: '142g', ratio: 0.75, color: const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _MacroItem(label: 'Carbs', value: '210g', ratio: 0.6, color: const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _MacroItem(label: 'Fat', value: '58g', ratio: 0.45, color: const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 32),
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Recent Meals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              _MealBriefItem(title: 'Breakfast', subtitle: 'Oatmeal, Banana, Whey', calories: '450 kcal', icon: Icons.wb_sunny_rounded),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 0.5, color: Color(0xFF262F36)),
              ),
              _MealBriefItem(title: 'Lunch', subtitle: 'Chicken Salad, Quinoa Bowl', calories: '620 kcal', icon: Icons.lunch_dining_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroItem extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _MacroItem({required this.label, required this.value, required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262F36)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                color: color,
                backgroundColor: color.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealBriefItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String calories;
  final IconData icon;

  const _MealBriefItem({required this.title, required this.subtitle, required this.calories, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Text(calories, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
      ],
    );
  }
}

class _MetricsTab extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _MetricsTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "Current Vitals",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MetricCard(label: 'Weight', value: '78.4', unit: 'kg', trend: '-0.5kg week', icon: Icons.monitor_weight_rounded, trendColor: Colors.green),
            const SizedBox(width: 16),
            _MetricCard(label: 'BMI', value: '23.2', unit: '', trend: 'Optimal Range', icon: Icons.accessibility_new_rounded),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String trend;
  final IconData icon;
  final Color? trendColor;

  const _MetricCard({required this.label, required this.value, required this.unit, required this.trend, required this.icon, this.trendColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E262C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF262F36)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  if (unit.isNotEmpty) TextSpan(text: ' $unit', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (trendColor ?? Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(trend, style: GoogleFonts.inter(color: trendColor ?? Colors.blue, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
