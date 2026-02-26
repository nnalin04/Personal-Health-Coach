import 'dart:math';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_provider.dart';

class ViewTrendsScreen extends ConsumerStatefulWidget {
  const ViewTrendsScreen({super.key});

  @override
  ConsumerState<ViewTrendsScreen> createState() => _ViewTrendsScreenState();
}

class _ViewTrendsScreenState extends ConsumerState<ViewTrendsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _metrics = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30)));
      final to = DateFormat('yyyy-MM-dd').format(now);

      final client = ref.read(apiClientProvider);
      final metricsRes = await client.get('/body-metrics', queryParameters: {'from': from, 'to': to});
      final summaryRes = await client.get('/health-summary/me');

      setState(() {
        _metrics = List<Map<String, dynamic>>.from(metricsRes.data as List);
        _summary = Map<String, dynamic>.from(summaryRes.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['message']?.toString() ?? 'Failed to load trends';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trends')),
        body: Center(child: Text(_error!)),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < _metrics.length; i++) {
      final weight = (_metrics[i]['weight'] as num?)?.toDouble();
      if (weight != null) {
        spots.add(FlSpot(i.toDouble(), weight));
      }
    }

    final nutrition = _summary?['nutrition_summary'] as Map<String, dynamic>?;
    final training = _summary?['training_summary'] as Map<String, dynamic>?;
    final medicalTrends = _summary?['medical_trends'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Trends'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Weight Progress (30d)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 24, 12),
              child: SizedBox(
                height: 200,
                child: spots.isEmpty
                    ? const Center(child: Text('No weight data yet'))
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: max(1, spots.length - 1).toDouble(),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              barWidth: 4,
                              color: Colors.blue,
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.1)),
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => Colors.blueAccent,
                            ),
                          ),
                          titlesData: const FlTitlesData(
                            leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 40)),
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Metabolic Markers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (medicalTrends != null && medicalTrends['status'] == null) ...[
            _MedicalTrendTile(title: 'Vitamin D', data: medicalTrends['vitamin_d']),
            _MedicalTrendTile(title: 'HbA1c', data: medicalTrends['hba1c']),
            _MedicalTrendTile(title: 'LDL Cholesterol', data: medicalTrends['ldl']),
            _MedicalTrendTile(title: 'Glucose', data: medicalTrends['glucose']),
          ] else
            const Card(
              child: ListTile(
                title: Text('Insufficient lab data for trends',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 24),
          const Text('Activity Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _MetricTile(
            title: 'Avg Protein (7d)',
            value: nutrition?['last_7_days']?['avg_protein']?.toString() ?? '--',
            unit: 'g',
          ),
          _MetricTile(
            title: 'Workout Frequency',
            value:
                training?['workout_frequency']?['last_30_days']?.toString() ??
                    '--',
            unit: 'sessions/wk',
          ),
          _MetricTile(
            title: 'Daily Steps (Avg)',
            value: training?['step_average']?['last_30_days']?.toString() ?? '--',
            unit: 'steps',
          ),
        ],
      ),
    );
  }
}

class _MedicalTrendTile extends StatelessWidget {
  final String title;
  final dynamic data;

  const _MedicalTrendTile({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    final direction = data['direction']?.toString() ?? 'unknown';
    final change = data['change'];

    Color color = Colors.grey;
    IconData icon = Icons.remove;

    if (direction == 'improved') {
      color = Colors.green;
      icon = Icons.trending_up;
    } else if (direction == 'worsened') {
      color = Colors.red;
      icon = Icons.trending_down;
    }

    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text('Latest: ${data['latest'] ?? '--'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (change != null)
              Text(
                '${change > 0 ? "+" : ""}$change',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            const SizedBox(width: 8),
            Icon(icon, color: color),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const _MetricTile(
      {required this.title, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text('$value $unit',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
