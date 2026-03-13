import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/cache/local_cache.dart';
import '../auth/auth_provider.dart';
import '../body_metrics/add_body_metrics_screen.dart';
import '../food/add_food_screen.dart';
import '../workout/add_workout_screen.dart';

class LoggingScreen extends ConsumerStatefulWidget {
  const LoggingScreen({super.key});

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _foods = [];
  List<Map<String, dynamic>> _metrics = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    // Show cached data immediately so the user is never in the dark
    final cachedWorkouts = LocalCache.get<List>('logs_workouts');
    final cachedFoods = LocalCache.get<List>('logs_foods');
    final cachedMetrics = LocalCache.get<List>('logs_metrics');
    if (cachedWorkouts != null || cachedFoods != null || cachedMetrics != null) {
      setState(() {
        if (cachedWorkouts != null) _workouts = List<Map<String, dynamic>>.from(cachedWorkouts);
        if (cachedFoods != null) _foods = List<Map<String, dynamic>>.from(cachedFoods);
        if (cachedMetrics != null) _metrics = List<Map<String, dynamic>>.from(cachedMetrics);
        _loading = false;
      });
    } else {
      setState(() { _loading = true; _error = null; });
    }

    // Then fetch fresh data from network in background
    try {
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30)));
      final to = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final client = ref.read(apiClientProvider);

      final results = await Future.wait([
        client.get('/workouts', queryParameters: {'from': from, 'to': to}),
        client.get('/foods', queryParameters: {'from': from, 'to': to}),
        client.get('/body-metrics', queryParameters: {'from': from, 'to': to}),
      ]);

      final freshWorkouts = List<Map<String, dynamic>>.from(results[0].data as List);
      final freshFoods = List<Map<String, dynamic>>.from(results[1].data as List);
      final freshMetrics = List<Map<String, dynamic>>.from(results[2].data as List);

      // Persist to cache (5 minute TTL — data changes frequently)
      await Future.wait([
        LocalCache.put('logs_workouts', freshWorkouts, ttlSeconds: 300),
        LocalCache.put('logs_foods', freshFoods, ttlSeconds: 300),
        LocalCache.put('logs_metrics', freshMetrics, ttlSeconds: 300),
      ]);

      if (mounted) {
        setState(() {
          _workouts = freshWorkouts;
          _foods = freshFoods;
          _metrics = freshMetrics;
          _loading = false;
          _error = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          // Only show error if we have no cached data to show
          if (_workouts.isEmpty && _foods.isEmpty && _metrics.isEmpty) {
            _error = e.response?.data?['message']?.toString() ?? 'No connection — showing last cached data';
          }
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAdd(BuildContext context) {
    final routes = [
      const AddWorkoutScreen(),
      const AddFoodScreen(),
      const AddBodyMetricsScreen(),
    ];
    final screen = routes[_tabController.index];
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadData());
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
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WorkoutsTab(workouts: _workouts),
                      _NutritionTab(foods: _foods),
                      _MetricsTab(metrics: _metrics),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAdd(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}

// ─── Workouts Tab ──────────────────────────────────────────────────────────────

class _WorkoutsTab extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;
  const _WorkoutsTab({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const Center(child: Text('No workouts logged yet.', style: TextStyle(color: Colors.grey)));
    }

    // Sort newest first
    final sorted = [...workouts]..sort((a, b) {
        final da = a['date'] as String? ?? '';
        final db = b['date'] as String? ?? '';
        return db.compareTo(da);
      });

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final w = sorted[i];
        final name = w['exerciseName'] as String? ?? 'Workout';
        final sets = w['sets'] as int? ?? 0;
        final reps = w['reps'] as int? ?? 0;
        final weight = (w['weight'] as num?)?.toDouble() ?? 0;
        final date = w['date'] as String? ?? '';
        final dateLabel = date.isNotEmpty
            ? DateFormat('MMM d').format(DateTime.parse(date))
            : '';

        return _WorkoutItem(
          title: name,
          subtitle: '$sets sets × $reps reps${weight > 0 ? ' · ${weight.toStringAsFixed(1)} kg' : ''}',
          trailing: dateLabel,
          icon: Icons.fitness_center_rounded,
        );
      },
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
          Text(trailing, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── Nutrition Tab ─────────────────────────────────────────────────────────────

class _NutritionTab extends StatelessWidget {
  final List<Map<String, dynamic>> foods;
  const _NutritionTab({required this.foods});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (foods.isEmpty) {
      return const Center(child: Text('No meals logged yet.', style: TextStyle(color: Colors.grey)));
    }

    // Aggregate today's totals
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayFoods = foods.where((f) => (f['date'] as String? ?? '') == today).toList();
    final totalCalories = todayFoods.fold<double>(0, (s, f) => s + ((f['calories'] as num?)?.toDouble() ?? 0));
    final totalProtein = todayFoods.fold<double>(0, (s, f) => s + ((f['protein'] as num?)?.toDouble() ?? 0));
    final totalCarbs = todayFoods.fold<double>(0, (s, f) => s + ((f['carbs'] as num?)?.toDouble() ?? 0));
    final totalFats = todayFoods.fold<double>(0, (s, f) => s + ((f['fats'] as num?)?.toDouble() ?? 0));

    // Sort newest first
    final sorted = [...foods]..sort((a, b) {
        final da = a['date'] as String? ?? '';
        final db = b['date'] as String? ?? '';
        return db.compareTo(da);
      });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary card
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
                        totalCalories.toStringAsFixed(0),
                        style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white),
                      ),
                      Text(
                        'kcal today',
                        style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _MacroItem(label: 'Protein', value: '${totalProtein.toStringAsFixed(0)}g', ratio: (totalProtein / 150).clamp(0, 1), color: const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _MacroItem(label: 'Carbs', value: '${totalCarbs.toStringAsFixed(0)}g', ratio: (totalCarbs / 250).clamp(0, 1), color: const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _MacroItem(label: 'Fat', value: '${totalFats.toStringAsFixed(0)}g', ratio: (totalFats / 80).clamp(0, 1), color: const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Recent Meals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              ...sorted.take(5).map((food) {
                final name = food['foodName'] as String? ?? 'Food';
                final meal = food['mealType'] as String? ?? '';
                final cal = (food['calories'] as num?)?.toDouble() ?? 0;
                final icon = _mealIcon(meal);
                return Column(
                  children: [
                    _MealBriefItem(
                      title: meal,
                      subtitle: name,
                      calories: '${cal.toStringAsFixed(0)} kcal',
                      icon: icon,
                    ),
                    if (sorted.indexOf(food) < sorted.take(5).length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, thickness: 0.5, color: Color(0xFF262F36)),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  IconData _mealIcon(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast': return Icons.wb_sunny_rounded;
      case 'lunch':     return Icons.lunch_dining_rounded;
      case 'dinner':    return Icons.dinner_dining_rounded;
      case 'snack':     return Icons.cookie_rounded;
      default:          return Icons.restaurant_rounded;
    }
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
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(10)),
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

// ─── Metrics Tab ───────────────────────────────────────────────────────────────

class _MetricsTab extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;
  const _MetricsTab({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Center(child: Text('No metrics logged yet.', style: TextStyle(color: Colors.grey)));
    }

    final sorted = [...metrics]..sort((a, b) {
        final da = a['date'] as String? ?? '';
        final db = b['date'] as String? ?? '';
        return db.compareTo(da);
      });

    final latest = sorted.first;
    final latestWeight = (latest['weight'] as num?)?.toDouble();
    final latestBmi = (latest['bmi'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Current Vitals', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        Row(
          children: [
            _MetricCard(
              label: 'Weight',
              value: latestWeight != null ? latestWeight.toStringAsFixed(1) : '--',
              unit: 'kg',
              trend: 'Last 30 days',
              icon: Icons.monitor_weight_rounded,
            ),
            const SizedBox(width: 16),
            _MetricCard(
              label: 'BMI',
              value: latestBmi != null ? latestBmi.toStringAsFixed(1) : '--',
              unit: '',
              trend: latestBmi != null ? _bmiCategory(latestBmi) : '--',
              icon: Icons.accessibility_new_rounded,
              trendColor: latestBmi != null ? _bmiColor(latestBmi) : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('History', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...sorted.map((m) {
          final date = m['date'] as String? ?? '';
          final w = (m['weight'] as num?)?.toDouble();
          final bmi = (m['bmi'] as num?)?.toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E262C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262F36)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date.isNotEmpty ? DateFormat('MMM d, yyyy').format(DateTime.parse(date)) : '',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                if (w != null)
                  Text('${w.toStringAsFixed(1)} kg', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                if (bmi != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('BMI ${bmi.toStringAsFixed(1)}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Optimal Range';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.red;
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
