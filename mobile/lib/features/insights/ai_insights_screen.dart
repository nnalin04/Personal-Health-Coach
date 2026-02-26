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
        _insights = Map<String, dynamic>.from(root['ai_insights']);
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
    return Scaffold(
      appBar: AppBar(title: const Text('AI Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _generateInsights,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Personalized Insights'),
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_insights != null) ...[
            _InsightSection(
              title: 'Diet Suggestions',
              items: List<String>.from(_insights!['dietSuggestions'] ?? []),
            ),
            _InsightSection(
              title: 'Training Suggestions',
              items: List<String>.from(_insights!['trainingSuggestions'] ?? []),
            ),
            _InsightSection(
              title: 'Recovery Suggestions',
              items: List<String>.from(_insights!['recoverySuggestions'] ?? []),
            ),
            _InsightSection(
              title: 'Medical Awareness Notes',
              items: List<String>.from(_insights!['medicalAwarenessNotes'] ?? []),
            ),
            const SizedBox(height: 8),
            Text(
              _insights!['disclaimer']?.toString() ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InsightSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $item'),
                )),
          ],
        ),
      ),
    );
  }
}
