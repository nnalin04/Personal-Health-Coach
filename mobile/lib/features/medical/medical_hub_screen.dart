import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'upload_medical_report_screen.dart';

class MedicalHubScreen extends StatelessWidget {
  const MedicalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
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

          // Biomarker Gauges
          _BiomarkerGauge(
            label: 'Vitamin D',
            value: 42.5,
            min: 30.0,
            max: 100.0,
            unit: 'ng/mL',
            status: 'Optimal',
          ),
          const SizedBox(height: 16),
          _BiomarkerGauge(
            label: 'LDL Cholesterol',
            value: 115.0,
            min: 0.0,
            max: 100.0,
            unit: 'mg/dL',
            status: 'Elevated',
            isWarning: true,
          ),
          const SizedBox(height: 16),
          _BiomarkerGauge(
            label: 'Fasting Glucose',
            value: 88,
            min: 70,
            max: 99,
            unit: 'mg/dL',
            status: 'Normal',
          ),
          
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
          _ReportTile(
            title: 'Annual Blood Work',
            date: 'Feb 12, 2024',
            status: 'Analyzed',
          ),
          _ReportTile(
            title: 'Lipid Panel',
            date: 'Jan 05, 2024',
            status: 'Analyzed',
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const UploadMedicalReportScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload New Report', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
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
    
    // Simple calculation for marker position
    double rangeLen = max - 0; // Assuming 0 is the start for visual simplicity
    double position = (value / rangeLen).clamp(0.0, 1.0);
    double healthyStart = (min / rangeLen).clamp(0.0, 1.0);
    double healthyEnd = (max / rangeLen).clamp(0.0, 1.0);

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
                style: GoogleFonts.inter(
                  color: indicatorColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
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
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Healthy Range Background (Simulated)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.2, // Rough simulation
                right: MediaQuery.of(context).size.width * 0.1,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Marker
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    margin: EdgeInsets.only(left: constraints.maxWidth * position - 4),
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: indicatorColor.withOpacity(0.5), blurRadius: 4),
                      ],
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
              Text('Range: $min - $max', style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
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
      margin: const EdgeInsets.only(bottom: 12),
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
