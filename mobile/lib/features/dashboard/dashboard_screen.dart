import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../body_metrics/add_body_metrics_screen.dart';
import '../food/add_food_screen.dart';
import '../medical/upload_medical_report_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await ref.read(apiClientProvider).get('/health-summary/me');
      setState(() {
        _summary = Map<String, dynamic>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = _summary?['nutrition_summary']?['last_7_days'];
    final training = _summary?['training_summary'];

    return Scaffold(
      appBar: AppBar(title: const Text('Health Coach')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader(title: 'Activity Highlights'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Steps (Avg)',
                          value: training?['step_average']?['last_7_days']
                                  ?.toString() ??
                              '0',
                          unit: 'steps',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Calories (Avg)',
                          value:
                              nutrition?['avg_calories']?.toString() ?? '0',
                          unit: 'kcal',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Actions'),
                  const SizedBox(height: 12),
                  _ActionGrid(),
                  if (_summary?['risk_flags'] != null &&
                      (_summary!['risk_flags'] as List).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Health Alerts'),
                    const SizedBox(height: 12),
                    ...(_summary!['risk_flags'] as List).map((flag) => Card(
                          color: Colors.red.shade50,
                          child: ListTile(
                            leading:
                                const Icon(Icons.warning, color: Colors.red),
                            title: Text(flag.toString(),
                                style: const TextStyle(fontSize: 13)),
                          ),
                        )),
                  ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Workout'),
              onTap: () {
                Navigator.pop(context);
                _open(context, const AddWorkoutScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Food'),
              onTap: () {
                Navigator.pop(context);
                _open(context, const AddFoodScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('Steps'),
              onTap: () {
                Navigator.pop(context);
                _open(context, const AddStepsScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(width: 4),
                Text(unit,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _ActionItem(
            icon: Icons.monitor_weight,
            title: 'Metrics',
            screen: const AddBodyMetricsScreen()),
        _ActionItem(
            icon: Icons.upload_file,
            title: 'Medical',
            screen: const UploadMedicalReportScreen()),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget screen;

  const _ActionItem(
      {required this.icon, required this.title, required this.screen});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
      icon: Icon(icon, size: 18),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
