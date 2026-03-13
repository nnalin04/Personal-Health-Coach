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

  // Nutrition intelligence state
  bool _nutrientLoading = false;
  String? _nutrientError;
  Map<String, dynamic>? _nutrientRecs;

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

  Future<void> _generateNutrientRecs() async {
    setState(() {
      _nutrientLoading = true;
      _nutrientError = null;
    });
    try {
      final response = await ref.read(apiClientProvider).post('/nutrient/recommendations');
      setState(() {
        _nutrientRecs = Map<String, dynamic>.from(response.data);
        _nutrientLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _nutrientError = e.response?.data is Map
            ? e.response?.data['detail']?.toString() ?? 'Failed to get recommendations'
            : 'Recommendations unavailable';
        _nutrientLoading = false;
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
        // ── Nutrition Intelligence section ──────────────────────────
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 18, color: Colors.teal),
                    const SizedBox(width: 6),
                    const Text(
                      'Nutrition Intelligence',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Deficiency analysis + culturally-aware food recommendations.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _nutrientLoading ? null : _generateNutrientRecs,
                    icon: _nutrientLoading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restaurant_outlined, size: 16),
                    label: Text(_nutrientLoading ? 'Analysing...' : 'Get Nutrition Recommendations'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_nutrientError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_nutrientError!, style: const TextStyle(color: Colors.red)),
          ),
        if (_nutrientRecs != null) ...[
          const SizedBox(height: 10),
          _NutrientRecsSection(data: _nutrientRecs!),
        ],

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

class _NutrientRecsSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NutrientRecsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final insights = data['deficiencyInsights'] as List<dynamic>? ?? [];
    final foods = data['foodRecommendations'] as List<dynamic>? ?? [];
    final supplements = data['supplementSuggestions'] as List<dynamic>? ?? [];

    if (insights.isEmpty && foods.isEmpty && supplements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No deficiencies detected — your nutrition looks balanced!'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insights.isNotEmpty) ...[
          _NutrientCard(
            title: 'Deficiency Insights',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            children: insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i['nutrient'] ?? ''} — ${i['level'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (i['impact'] != null)
                    Text('Impact: ${i['impact']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )).toList(),
          ),
        ],
        if (foods.isNotEmpty) ...[
          _NutrientCard(
            title: 'Food Recommendations',
            icon: Icons.set_meal_rounded,
            color: Colors.green,
            children: foods.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f['food'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (f['for_deficiency'] != null)
                    Text('For: ${f['for_deficiency']}',
                        style: const TextStyle(fontSize: 11, color: Colors.teal)),
                  if (f['reason'] != null)
                    Text(f['reason'], style: const TextStyle(fontSize: 12)),
                  if (f['how_to_add'] != null)
                    Text('→ ${f['how_to_add']}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            )).toList(),
          ),
        ],
        if (supplements.isNotEmpty) ...[
          _NutrientCard(
            title: 'Supplement Suggestions',
            icon: Icons.medication_outlined,
            color: Colors.blue,
            children: supplements.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['supplement'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (s['reason'] != null)
                    Text(s['reason'], style: const TextStyle(fontSize: 12)),
                  if (s['food_alternative'] != null)
                    Text('Food option: ${s['food_alternative']}',
                        style: const TextStyle(fontSize: 12, color: Colors.teal)),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _NutrientCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _NutrientCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
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
