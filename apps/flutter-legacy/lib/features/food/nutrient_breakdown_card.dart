import 'package:flutter/material.dart';

/// Displays the micronutrient breakdown returned by the AI food analysis.
/// [nutrients] is the `nutrients` map from the API response.
/// [foods] is the list of identified food items.
class NutrientBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> nutrients;
  final List<dynamic> foods;
  final String? confidenceNote;

  const NutrientBreakdownCard({
    super.key,
    required this.nutrients,
    required this.foods,
    this.confidenceNote,
  });

  @override
  Widget build(BuildContext context) {
    final vitamins = nutrients['vitamins'] as Map<String, dynamic>? ?? {};
    final minerals = nutrients['minerals'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, size: 18, color: Colors.teal),
                const SizedBox(width: 6),
                Text(
                  'Nutrient Analysis',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                ),
              ],
            ),
            if (foods.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: foods.map<Widget>((f) {
                  final name = f['name']?.toString() ?? '';
                  final portion = f['portion_g'];
                  return Chip(
                    label: Text(
                      portion != null ? '$name (~${portion}g)' : name,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (vitamins.isNotEmpty) ...[
              _SectionHeader(title: 'Vitamins'),
              const SizedBox(height: 6),
              _NutrientGrid(entries: _buildVitaminEntries(vitamins)),
              const SizedBox(height: 10),
            ],
            if (minerals.isNotEmpty) ...[
              _SectionHeader(title: 'Minerals'),
              const SizedBox(height: 6),
              _NutrientGrid(entries: _buildMineralEntries(minerals)),
            ],
            if (confidenceNote != null && confidenceNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                confidenceNote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_NutrientEntry> _buildVitaminEntries(Map<String, dynamic> v) {
    return [
      _NutrientEntry('Vit A', v['a_mcg'], 'mcg'),
      _NutrientEntry('Vit B1', v['b1_mg'], 'mg'),
      _NutrientEntry('Vit B2', v['b2_mg'], 'mg'),
      _NutrientEntry('Vit B3', v['b3_mg'], 'mg'),
      _NutrientEntry('Vit B6', v['b6_mg'], 'mg'),
      _NutrientEntry('Folate', v['b9_mcg'], 'mcg'),
      _NutrientEntry('Vit B12', v['b12_mcg'], 'mcg'),
      _NutrientEntry('Vit C', v['c_mg'], 'mg'),
      _NutrientEntry('Vit D', v['d_mcg'], 'mcg'),
      _NutrientEntry('Vit E', v['e_mg'], 'mg'),
      _NutrientEntry('Vit K', v['k_mcg'], 'mcg'),
    ].where((e) => e.value != null).toList();
  }

  List<_NutrientEntry> _buildMineralEntries(Map<String, dynamic> m) {
    return [
      _NutrientEntry('Calcium', m['calcium_mg'], 'mg'),
      _NutrientEntry('Iron', m['iron_mg'], 'mg'),
      _NutrientEntry('Zinc', m['zinc_mg'], 'mg'),
      _NutrientEntry('Magnesium', m['magnesium_mg'], 'mg'),
      _NutrientEntry('Potassium', m['potassium_mg'], 'mg'),
      _NutrientEntry('Selenium', m['selenium_mcg'], 'mcg'),
      _NutrientEntry('Iodine', m['iodine_mcg'], 'mcg'),
    ].where((e) => e.value != null).toList();
  }
}

class _NutrientEntry {
  final String label;
  final dynamic value;
  final String unit;
  const _NutrientEntry(this.label, this.value, this.unit);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 0.8,
          ),
    );
  }
}

class _NutrientGrid extends StatelessWidget {
  final List<_NutrientEntry> entries;
  const _NutrientGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: entries.map((e) {
        final val = e.value is num ? (e.value as num).toStringAsFixed(1) : '?';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${e.label}: $val ${e.unit}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      }).toList(),
    );
  }
}
