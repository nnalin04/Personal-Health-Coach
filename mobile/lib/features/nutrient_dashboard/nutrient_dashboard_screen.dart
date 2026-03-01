import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

class NutrientDashboardScreen extends ConsumerStatefulWidget {
  const NutrientDashboardScreen({super.key});

  @override
  ConsumerState<NutrientDashboardScreen> createState() => _NutrientDashboardScreenState();
}

class _NutrientDashboardScreenState extends ConsumerState<NutrientDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _trend;

  // nutrient key → display label (matches RdaConstants + nutrient_logs columns)
  static const Map<String, String> _nutrients = {
    'vitamin_a': 'Vit A',
    'vitamin_c': 'Vit C',
    'vitamin_d': 'Vit D',
    'vitamin_e': 'Vit E',
    'vitamin_k': 'Vit K',
    'vitamin_b1': 'B1',
    'vitamin_b2': 'B2',
    'vitamin_b6': 'B6',
    'vitamin_b12': 'B12',
    'folate': 'Folate',
    'niacin': 'Niacin',
    'calcium': 'Ca',
    'iron': 'Iron',
    'magnesium': 'Mg',
    'phosphorus': 'P',
    'potassium': 'K',
    'sodium': 'Na',
    'zinc': 'Zn',
  };

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
      final res = await ref.read(apiClientProvider).get('/nutrient/weekly-trends');
      setState(() {
        _trend = Map<String, dynamic>.from(res.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'Failed to load trends'
            : 'Failed to load nutrient trends';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micronutrient Tracker'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _TrendBody(trend: _trend!, nutrients: _nutrients),
                ),
    );
  }
}

// ── Error ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Trend Body ───────────────────────────────────────────────────────────────

class _TrendBody extends StatelessWidget {
  final Map<String, dynamic> trend;
  final Map<String, String> nutrients;

  const _TrendBody({required this.trend, required this.nutrients});

  @override
  Widget build(BuildContext context) {
    final days = (trend['dailyBreakdowns'] as List<dynamic>? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    final chronic = List<String>.from(trend['chronicDeficiencies'] ?? []);
    final tracked = (trend['totalDaysTracked'] as int?) ?? 0;
    final weekStart = trend['weekStart']?.toString() ?? '';
    final weekEnd = trend['weekEnd']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _DateRangeRow(weekStart: weekStart, weekEnd: weekEnd, tracked: tracked),
        const SizedBox(height: 12),

        if (chronic.isNotEmpty) ...[
          _DeficiencyWarning(nutrients: chronic),
          const SizedBox(height: 14),
        ],

        if (days.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No nutrient data yet.\nLog some meals to start tracking micronutrients.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else ...[
          _Legend(),
          const SizedBox(height: 12),
          _Heatmap(days: days, nutrients: nutrients),
          const SizedBox(height: 16),
          _SummaryStats(days: days, nutrients: nutrients),
        ],
      ],
    );
  }
}

// ── Date Range Row ────────────────────────────────────────────────────────────

class _DateRangeRow extends StatelessWidget {
  final String weekStart;
  final String weekEnd;
  final int tracked;

  const _DateRangeRow({
    required this.weekStart,
    required this.weekEnd,
    required this.tracked,
  });

  String _fmt(String raw) {
    if (raw.length < 10) return raw;
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = weekStart.isNotEmpty && weekEnd.isNotEmpty
        ? '${_fmt(weekStart)} – ${_fmt(weekEnd)}'
        : 'Last 7 days';

    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
        const SizedBox(width: 6),
        Text(range, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text(
          '$tracked / 7 days tracked',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// ── Chronic Deficiency Warning ────────────────────────────────────────────────

class _DeficiencyWarning extends StatelessWidget {
  final List<String> nutrients;

  const _DeficiencyWarning({required this.nutrients});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Chronic deficiencies (4+ days below RDA)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: nutrients
                .map((n) => Chip(
                      label: Text(n, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.orange.shade100,
                      side: BorderSide(color: Colors.orange.shade300),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: const [
        _LegendDot(color: Color(0xFF66BB6A), label: '≥80% RDA'),
        _LegendDot(color: Color(0xFFFFCA28), label: '50–79%'),
        _LegendDot(color: Color(0xFFEF5350), label: '<50%'),
        _LegendDot(color: Color(0xFFE0E0E0), label: 'No data'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final Map<String, String> nutrients;

  const _Heatmap({required this.days, required this.nutrients});

  Color _cellColor(double? pct) {
    if (pct == null || pct == 0) return const Color(0xFFE0E0E0);
    if (pct >= 80) return const Color(0xFF66BB6A);
    if (pct >= 50) return const Color(0xFFFFCA28);
    return const Color(0xFFEF5350);
  }

  Color _textColor(double? pct) {
    if (pct == null || pct == 0) return Colors.grey;
    if (pct >= 50) return Colors.black87;
    return Colors.white;
  }

  String _dayLabel(String raw) {
    if (raw.length < 10) return raw;
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('E').format(dt); // Mon, Tue…
    } catch (_) {
      return raw.substring(5); // MM-DD fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    const labelWidth = 48.0;
    const cellSize = 34.0;
    const cellGap = 3.0;

    final dayLabels = days.map((d) => _dayLabel(d['date']?.toString() ?? '')).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7-Day Micronutrient Heatmap',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    children: [
                      SizedBox(width: labelWidth),
                      ...dayLabels.map((d) => SizedBox(
                            width: cellSize + cellGap,
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                              ),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Nutrient rows
                  ...nutrients.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: cellGap),
                      child: Row(
                        children: [
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...days.map((day) {
                            final percMap =
                                day['percentOfRda'] as Map<String, dynamic>? ?? {};
                            final pct = (percMap[entry.key] as num?)?.toDouble();
                            return Container(
                              width: cellSize,
                              height: cellSize,
                              margin: const EdgeInsets.only(right: cellGap),
                              decoration: BoxDecoration(
                                color: _cellColor(pct),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: pct != null && pct > 0
                                  ? Center(
                                      child: Text(
                                        '${pct.round()}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: _textColor(pct),
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Stats ─────────────────────────────────────────────────────────────

class _SummaryStats extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final Map<String, String> nutrients;

  const _SummaryStats({required this.days, required this.nutrients});

  @override
  Widget build(BuildContext context) {
    // Compute per-nutrient average % across tracked days
    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final day in days) {
      final percMap = day['percentOfRda'] as Map<String, dynamic>? ?? {};
      for (final key in nutrients.keys) {
        final pct = (percMap[key] as num?)?.toDouble();
        if (pct != null && pct > 0) {
          totals[key] = (totals[key] ?? 0) + pct;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }

    final avgs = <MapEntry<String, double>>[];
    for (final key in nutrients.keys) {
      final cnt = counts[key] ?? 0;
      if (cnt > 0) {
        avgs.add(MapEntry(key, totals[key]! / cnt));
      }
    }

    if (avgs.isEmpty) return const SizedBox.shrink();

    avgs.sort((a, b) => a.value.compareTo(b.value));
    final lowest = avgs.take(3).toList();
    final highest = avgs.reversed.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCard(
          title: 'Needs attention',
          icon: Icons.arrow_downward_rounded,
          iconColor: Colors.red,
          entries: lowest,
          nutrients: nutrients,
        ),
        const SizedBox(height: 10),
        _StatCard(
          title: 'Well covered',
          icon: Icons.arrow_upward_rounded,
          iconColor: Colors.green,
          entries: highest,
          nutrients: nutrients,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<MapEntry<String, double>> entries;
  final Map<String, String> nutrients;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.entries,
    required this.nutrients,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: iconColor,
                  ),
                ),
                const Text(
                  ' — 7-day avg',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...entries.map((e) {
              final label = nutrients[e.key] ?? e.key;
              final pct = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: (pct / 100).clamp(0, 1),
                          color: pct >= 80
                              ? const Color(0xFF66BB6A)
                              : pct >= 50
                                  ? const Color(0xFFFFCA28)
                                  : const Color(0xFFEF5350),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${pct.round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
