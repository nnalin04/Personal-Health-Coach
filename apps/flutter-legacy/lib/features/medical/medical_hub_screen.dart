import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/cache/local_cache.dart';
import '../auth/auth_provider.dart';
import 'upload_medical_report_screen.dart';

// Biomarker metadata: key (JSON field), label, unit, normalMin, normalMax
const _biomarkers = [
  {'key': 'vitaminD',    'label': 'Vitamin D',        'unit': 'ng/mL', 'min': 30.0,  'max': 100.0},
  {'key': 'glucose',     'label': 'Fasting Glucose',  'unit': 'mg/dL', 'min': 70.0,  'max': 99.0},
  {'key': 'ldl',         'label': 'LDL Cholesterol',  'unit': 'mg/dL', 'min': 0.0,   'max': 100.0},
  {'key': 'hdl',         'label': 'HDL Cholesterol',  'unit': 'mg/dL', 'min': 40.0,  'max': 200.0},
  {'key': 'triglycerides','label': 'Triglycerides',   'unit': 'mg/dL', 'min': 0.0,   'max': 150.0},
  {'key': 'hba1c',       'label': 'HbA1c',            'unit': '%',     'min': 0.0,   'max': 5.7},
  {'key': 'hemoglobin',  'label': 'Hemoglobin',       'unit': 'g/dL',  'min': 13.5,  'max': 17.5},
  {'key': 'creatinine',  'label': 'Creatinine',       'unit': 'mg/dL', 'min': 0.7,   'max': 1.3},
  {'key': 'tsh',         'label': 'TSH',              'unit': 'mIU/L', 'min': 0.4,   'max': 4.0},
  {'key': 'alt',         'label': 'ALT',              'unit': 'U/L',   'min': 7.0,   'max': 40.0},
  {'key': 'ast',         'label': 'AST',              'unit': 'U/L',   'min': 10.0,  'max': 40.0},
  {'key': 'testosterone','label': 'Testosterone',     'unit': 'ng/dL', 'min': 300.0, 'max': 1000.0},
];

class MedicalHubScreen extends ConsumerStatefulWidget {
  const MedicalHubScreen({super.key});

  @override
  ConsumerState<MedicalHubScreen> createState() => _MedicalHubScreenState();
}

class _MedicalHubScreenState extends ConsumerState<MedicalHubScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Show cached reports immediately
    final cached = LocalCache.get<List>('medical_reports');
    if (cached != null) {
      setState(() {
        _reports = List<Map<String, dynamic>>.from(cached);
        _loading = false;
      });
    } else {
      setState(() { _loading = true; _error = null; });
    }

    try {
      final res = await ref.read(apiClientProvider).get('/medical/reports');
      final fresh = List<Map<String, dynamic>>.from(res.data as List);
      await LocalCache.put('medical_reports', fresh); // No TTL — reports don't change often
      if (mounted) {
        setState(() {
          _reports = fresh;
          _loading = false;
          _error = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          if (_reports.isEmpty) {
            _error = e.response?.data?['message']?.toString() ?? 'No connection — showing cached data';
          }
          _loading = false;
        });
      }
    }
  }

  // Returns the labs map of the most recent report that has labs.
  Map<String, dynamic>? get _latestLabs {
    for (final report in _reports) {
      final labs = report['labs'] as List?;
      if (labs != null && labs.isNotEmpty) {
        return Map<String, dynamic>.from(labs.first as Map);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Biomarker Insights',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.info_outline_rounded, size: 20),
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visual summary of your latest lab results compared to healthy reference ranges.',
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._buildBiomarkerGauges(),
                      const SizedBox(height: 32),
                      Text(
                        'Recent Reports',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._buildReportTiles(theme),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const UploadMedicalReportScreen()),
                            );
                            _load(); // Refresh after returning from upload
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Upload New Report', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  List<Widget> _buildBiomarkerGauges() {
    final labs = _latestLabs;
    if (labs == null) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E262C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF262F36)),
          ),
          child: const Center(
            child: Text(
              'No lab results yet.\nUpload a medical report to see your biomarkers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ];
    }

    final gauges = <Widget>[];
    for (final config in _biomarkers) {
      final value = labs[config['key']];
      if (value == null) continue;
      final v = (value as num).toDouble();
      final min = config['min']! as double;
      final max = config['max']! as double;
      final isWarning = v < min || v > max;
      gauges.add(_BiomarkerGauge(
        label: config['label']! as String,
        value: v,
        min: min,
        max: max,
        unit: config['unit']! as String,
        status: isWarning ? (v > max ? 'Elevated' : 'Low') : 'Normal',
        isWarning: isWarning,
      ));
      gauges.add(const SizedBox(height: 16));
    }
    return gauges;
  }

  List<Widget> _buildReportTiles(ThemeData theme) {
    if (_reports.isEmpty) {
      return [
        const Center(
          child: Text('No reports uploaded yet.', style: TextStyle(color: Colors.grey)),
        ),
      ];
    }
    return _reports.map((report) {
      final dateStr = report['reportDate'] as String? ?? '';
      final date = dateStr.isNotEmpty
          ? DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr))
          : 'Unknown date';
      final labs = report['labs'] as List?;
      final status = (labs != null && labs.isNotEmpty) ? 'Analyzed' : 'Pending';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ReportTile(
          title: 'Medical Report',
          date: date,
          status: status,
        ),
      );
    }).toList();
  }
}

class _BiomarkerGauge extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final String status;
  final bool isWarning;

  const _BiomarkerGauge({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.status,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = isWarning ? Colors.orange : const Color(0xFF10B981);
    final rangeLen = max > 0 ? max * 1.5 : 1.0;
    final position = (value / rangeLen).clamp(0.0, 1.0);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                status,
                style: GoogleFonts.inter(color: indicatorColor, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    margin: EdgeInsets.only(left: (constraints.maxWidth * position - 4).clamp(0.0, constraints.maxWidth - 8)),
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: indicatorColor.withOpacity(0.5), blurRadius: 4)],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(color: Colors.grey.shade700, fontSize: 10)),
              Text('Normal: $min – $max', style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
              Text((max * 1.5).toStringAsFixed(0), style: TextStyle(color: Colors.grey.shade700, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String date;
  final String status;

  const _ReportTile({required this.title, required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF1E262C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF262F36)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description_rounded, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(date, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
