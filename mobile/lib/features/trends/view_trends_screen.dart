import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

enum TrendWindow { daily, weekly, monthly }

class ViewTrendsScreen extends ConsumerStatefulWidget {
  const ViewTrendsScreen({super.key});

  @override
  ConsumerState<ViewTrendsScreen> createState() => _ViewTrendsScreenState();
}

class _ViewTrendsScreenState extends ConsumerState<ViewTrendsScreen> {
  TrendWindow _window = TrendWindow.weekly;
  bool _loading = true;
  String? _error;
  bool _showStepsOverlay = false;

  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _steps = [];
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
      final from = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: _daysForWindow() - 1)));
      final to = DateFormat('yyyy-MM-dd').format(now);

      final client = ref.read(apiClientProvider);
      final responses = await Future.wait([
        client.get('/body-metrics', queryParameters: {'from': from, 'to': to}),
        client.get('/steps', queryParameters: {'from': from, 'to': to}),
        client.get('/health-summary/me'),
      ]);

      setState(() {
        _metrics = List<Map<String, dynamic>>.from(responses[0].data as List);
        _steps = List<Map<String, dynamic>>.from(responses[1].data as List);
        _summary = Map<String, dynamic>.from(responses[2].data as Map);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['message']?.toString() ?? 'Failed to load trends';
        _loading = false;
      });
    }
  }

  int _daysForWindow() {
    switch (_window) {
      case TrendWindow.daily: return 7;
      case TrendWindow.weekly: return 30;
      case TrendWindow.monthly: return 90;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final theme = Theme.of(context);
    final weightSpots = _weightSpots();
    final stepSpots = _stepSpots();
    
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Trends & Insights', 
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
          const SizedBox(height: 20),
          
          // Time Range Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TimeChip(label: '7D', selected: _window == TrendWindow.daily, onTap: () => _updateWindow(TrendWindow.daily)),
                const SizedBox(width: 8),
                _TimeChip(label: '30D', selected: _window == TrendWindow.weekly, onTap: () => _updateWindow(TrendWindow.weekly)),
                const SizedBox(width: 8),
                _TimeChip(label: '90D', selected: _window == TrendWindow.monthly, onTap: () => _updateWindow(TrendWindow.monthly)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Primary Chart Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E262C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF262F36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight Trend', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Goal: 75.0 kg', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Switch(
                      value: _showStepsOverlay,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (v) => setState(() => _showStepsOverlay = v),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 240,
                  child: weightSpots.length < 2
                      ? const Center(child: Text('Add more weight logs to see the trend'))
                      : LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBgColor: const Color(0xFF111827),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final isWeight = spot.barIndex == 0;
                                    return LineTooltipItem(
                                      '${isWeight ? 'Weight' : 'Steps'}: ${spot.y.toStringAsFixed(1)}${isWeight ? ' kg' : ''}',
                                      GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                            ),
                            titlesData: const FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: weightSpots,
                                isCurved: true,
                                color: theme.colorScheme.primary,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [theme.colorScheme.primary.withOpacity(0.2), theme.colorScheme.primary.withOpacity(0)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              if (_showStepsOverlay)
                                LineChartBarData(
                                  spots: stepSpots,
                                  isCurved: true,
                                  color: Colors.blueAccent.withOpacity(0.5),
                                  barWidth: 2,
                                  dashArray: [5, 5],
                                  dotData: const FlDotData(show: false),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Key Performance Indicators', 
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          _summaryTiles(),
        ],
      ),
    );
  }

  void _updateWindow(TrendWindow w) {
    setState(() => _window = w);
    _load();
  }

  List<FlSpot> _weightSpots() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _metrics.length; i++) {
      final weight = _metrics[i]['weight'];
      if (weight is num) spots.add(FlSpot(i.toDouble(), weight.toDouble()));
    }
    return spots;
  }

  List<FlSpot> _stepSpots() {
    final spots = <FlSpot>[];
    final subset = _steps.length <= 10 ? _steps : _steps.sublist(_steps.length - 10);
    if (_metrics.isEmpty || subset.isEmpty) return [];
    
    // Simple scaling for display alongside weight
    double minW = _metrics.map((e) => (e['weight'] as num?)?.toDouble() ?? 70).reduce(min);
    for (var i = 0; i < subset.length; i++) {
      final s = subset[i]['stepCount'];
      if (s is num) spots.add(FlSpot(i.toDouble(), minW + (s / 1000)));
    }
    return spots;
  }

  Widget _summaryTiles() {
    final nutrition = _summary?['nutrition_summary'] as Map<String, dynamic>?;
    final training = _summary?['training_summary'] as Map<String, dynamic>?;

    return Column(
      children: [
        _InsightTile(
          icon: Icons.bolt_rounded,
          color: Colors.amber,
          title: 'Daily Calorie Avg',
          value: '${nutrition?['last_7_days']?['avg_calories'] ?? '--'} kcal',
        ),
        _InsightTile(
          icon: Icons.restaurant_rounded,
          color: Colors.blue,
          title: 'Protein Consistency',
          value: '${nutrition?['last_7_days']?['avg_protein'] ?? '--'} g',
        ),
        _InsightTile(
          icon: Icons.calendar_today_rounded,
          color: Colors.green,
          title: 'Workout Frequency',
          value: '${training?['workout_frequency']?['last_30_days'] ?? '--'} /week',
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.grey)),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: theme.colorScheme.primary,
      side: BorderSide(color: selected ? Colors.transparent : const Color(0xFF262F36)),
      showCheckmark: false,
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _InsightTile({required this.icon, required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E262C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262F36)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14))),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;

  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
