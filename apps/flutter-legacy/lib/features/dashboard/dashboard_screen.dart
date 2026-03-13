import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';
import '../body_metrics/add_body_metrics_screen.dart';
import '../food/add_food_screen.dart';
import '../medical/upload_medical_report_screen.dart';
import '../nutrient_dashboard/nutrient_dashboard_screen.dart';
import '../steps/add_steps_screen.dart';
import '../workout/add_workout_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).get('/health-summary/me');
      setState(() {
        _summary = Map<String, dynamic>.from(res.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['message']?.toString() ?? 'Failed to load dashboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final nutrition = _summary?['nutrition_summary'] as Map<String, dynamic>?;
    final training = _summary?['training_summary'] as Map<String, dynamic>?;
    final weightTrend7d = (_summary?['weight_trend'] as Map<String, dynamic>?)?['last_7_days'] as Map<String, dynamic>?;
    final riskFlags = List<String>.from(_summary?['risk_flags'] ?? const []);

    final stepAvg = _num(training?['step_average']?['last_7_days']).round();
    final calories = _num(nutrition?['last_7_days']?['avg_calories']).round();
    final workouts = _num(training?['workout_frequency']?['last_7_days']);
    final score = _computeScore(riskFlags, stepAvg, workouts);

    final userEmail = ref.watch(authControllerProvider).user?['email'] as String? ?? '';
    final displayName = userEmail.contains('@') ? userEmail.split('@').first : userEmail;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const SizedBox(height: 16),
            // Stitch Header
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isNotEmpty ? displayName : 'Health Coach',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'PRO MEMBER',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _HealthScoreCard(score: score),
            const SizedBox(height: 24),
            
            // Quick Actions Grid
            Row(
              children: [
                _QuickActionTile(
                  icon: Icons.fitness_center_rounded,
                  label: 'WORKOUT',
                  bgColor: Colors.blue.withOpacity(0.1),
                  iconColor: Colors.blue,
                  onTap: () => _open(const AddWorkoutScreen()),
                ),
                const SizedBox(width: 12),
                _QuickActionTile(
                  icon: Icons.restaurant_rounded,
                  label: 'FOOD',
                  bgColor: Colors.orange.withOpacity(0.1),
                  iconColor: Colors.orange,
                  onTap: () => _open(const AddFoodScreen()),
                ),
                const SizedBox(width: 12),
                _QuickActionTile(
                  icon: Icons.add_chart_rounded,
                  label: 'METRIC',
                  bgColor: Colors.teal.withOpacity(0.1),
                  iconColor: Colors.teal,
                  onTap: () => _open(const AddBodyMetricsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nutrient Intelligence quick-access banner
            _NutrientBanner(onTap: () => _open(const NutrientDashboardScreen())),
            const SizedBox(height: 32),

            _SectionHeader(
              title: 'Daily Activity',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Details'),
              ),
            ),
            const SizedBox(height: 12),
            _ActivityProgressCard(
              title: 'Steps',
              icon: Icons.directions_walk_rounded,
              color: Colors.blue,
              value: stepAvg.toDouble(),
              target: 10000,
              unit: 'steps',
            ),
            const SizedBox(height: 12),
            _ActivityProgressCard(
              title: 'Calories',
              icon: Icons.local_fire_department_rounded,
              color: Colors.orange,
              value: calories.toDouble(),
              target: 2500,
              unit: 'kcal',
            ),
            const SizedBox(height: 12),
            _ActivityProgressCard(
              title: 'Active Minutes',
              icon: Icons.timer_rounded,
              color: Colors.teal,
              value: (workouts * 15).clamp(0, 60),
              target: 60,
              unit: 'min',
            ),
            const SizedBox(height: 32),
            _SectionHeader(title: 'Recent Trends', trailing: const Text('Weight (7 Days)')),
            const SizedBox(height: 16),
            _WeightTrendCard(trend: weightTrend7d),
          ],
        ),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  int _computeScore(List<String> riskFlags, int stepAvg, double workouts) {
    var score = 75;
    score += (stepAvg / 2000).floor().clamp(0, 10);
    if (workouts >= 3) score += 7;
    score -= riskFlags.length * 6;
    return score.clamp(25, 97);
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.8,
              ),
        ),
        trailing,
      ],
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final int score;

  const _HealthScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Intelligence Score',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$score',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ 100',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '+2 points from last week',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  color: Colors.white,
                ),
                const Center(
                  child: Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityProgressCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final double value;
  final double target;
  final String unit;

  const _ActivityProgressCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = target <= 0 ? 0 : (value / target).clamp(0, 1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Text(
                '${value.toInt()} / ${target.toInt()} $unit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio.toDouble(),
              color: color,
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _NutrientBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.science_outlined, color: Colors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Micronutrient Tracker',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Weekly vitamin & mineral heatmap',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.teal),
          ],
        ),
      ),
    );
  }
}

class _WeightTrendCard extends StatelessWidget {
  final Map<String, dynamic>? trend;

  const _WeightTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = trend?['start_weight'] as num?;
    final end = trend?['end_weight'] as num?;
    final change = trend?['change'] as num?;
    final direction = trend?['direction'] as String? ?? 'unknown';

    final hasData = start != null && end != null;
    final isDown = direction == 'down';
    final isUp = direction == 'up';
    final trendColor = isDown
        ? Colors.green
        : isUp
            ? Colors.orange
            : theme.colorScheme.onSurfaceVariant;
    final trendIcon = isDown
        ? Icons.trending_down_rounded
        : isUp
            ? Icons.trending_up_rounded
            : Icons.trending_flat_rounded;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: hasData
          ? Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${end!.toStringAsFixed(1)} kg',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        change != null
                            ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg vs 7 days ago (${start!.toStringAsFixed(1)} kg)'
                            : 'vs ${start!.toStringAsFixed(1)} kg 7 days ago',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Text(
              'No weight data recorded yet.\nLog body metrics to see your trend.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}


