import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

class AiInsightsScreen extends ConsumerStatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  ConsumerState<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends ConsumerState<AiInsightsScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _insights;

  Future<void> _generateInsights() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).post('/health-summary/me/ai-insights');
      final root = Map<String, dynamic>.from(response.data);
      setState(() {
        _insights = Map<String, dynamic>.from(root['ai_insights'] ?? {});
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['message']?.toString() ?? 'Failed to generate insights';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate structured personalized guidance from your latest summary.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _generateInsights,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(_loading ? 'Generating...' : 'Generate AI Insights'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_insights != null) ...[
          const SizedBox(height: 14),
          _InsightSection(
            title: 'Diet Suggestions',
            icon: Icons.restaurant_menu_rounded,
            items: List<String>.from(_insights!['dietSuggestions'] ?? const []),
          ),
          _InsightSection(
            title: 'Training Suggestions',
            icon: Icons.fitness_center_rounded,
            items: List<String>.from(_insights!['trainingSuggestions'] ?? const []),
          ),
          _InsightSection(
            title: 'Recovery Suggestions',
            icon: Icons.bedtime_rounded,
            items: List<String>.from(_insights!['recoverySuggestions'] ?? const []),
          ),
          _InsightSection(
            title: 'Medical Awareness Notes',
            icon: Icons.health_and_safety_rounded,
            items: List<String>.from(_insights!['medicalAwarenessNotes'] ?? const []),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _insights!['disclaimer']?.toString() ??
                    'This is informational guidance only and not medical diagnosis.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _InsightSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No items yet')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $item'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
