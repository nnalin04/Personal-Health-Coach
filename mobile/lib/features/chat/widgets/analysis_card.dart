import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum AnalysisType { food, medical }

class AnalysisCard extends StatelessWidget {
  final AnalysisType type;
  final Map<String, dynamic> data;

  const AnalysisCard({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFood = type == AnalysisType.food;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E262C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262F36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFood ? Icons.restaurant_rounded : Icons.medical_services_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFood ? 'Food Analysis' : 'Medical Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 16),
            ],
          ),
          const SizedBox(height: 20),
          if (isFood) ...[
            _DataRow(label: 'Calories', value: '${data['calories']} kcal'),
            _DataRow(label: 'Protein', value: '${data['protein']}g'),
            _DataRow(label: 'Carbs', value: '${data['carbs']}g'),
            _DataRow(label: 'Fat', value: '${data['fat']}g'),
          ] else ...[
            _DataRow(label: 'Status', value: data['status'] ?? 'Optimal'),
            _DataRow(label: 'Summary', value: data['finding'] ?? 'Healthy'),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View Full Details'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
