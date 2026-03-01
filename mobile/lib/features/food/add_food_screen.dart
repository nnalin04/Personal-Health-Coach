import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';
import 'nutrient_breakdown_card.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _mealType = TextEditingController();
  final _foodName = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fats = TextEditingController();
  final _calories = TextEditingController();
  final _describeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  // Nutrient analysis state
  bool _analyzingNutrients = false;
  Map<String, dynamic>? _nutrientResult;
  bool _showDescribeField = false;

  @override
  void dispose() {
    _mealType.dispose();
    _foodName.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    _calories.dispose();
    _describeController.dispose();
    super.dispose();
  }

  Future<void> _analyzeFromPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = picked.mimeType ?? 'image/jpeg';

    await _callNutrientAnalysis(imageBase64: base64Image, mimeType: mimeType);
  }

  Future<void> _analyzeFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = picked.mimeType ?? 'image/jpeg';

    await _callNutrientAnalysis(imageBase64: base64Image, mimeType: mimeType);
  }

  Future<void> _analyzeFromDescription() async {
    final desc = _describeController.text.trim();
    if (desc.isEmpty) return;

    // Pre-fill food name from description
    if (_foodName.text.isEmpty) {
      _foodName.text = desc;
    }
    await _callNutrientAnalysis(description: desc);
  }

  Future<void> _callNutrientAnalysis({
    String? imageBase64,
    String? mimeType,
    String? description,
  }) async {
    setState(() => _analyzingNutrients = true);
    try {
      final response = await ref.read(apiClientProvider).post(
        '/food/analyze-nutrients',
        data: {
          if (imageBase64 != null) 'image_base64': imageBase64,
          if (mimeType != null) 'image_mime_type': mimeType,
          if (description != null) 'description': description,
          'user_context': {},
        },
      );

      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;

      // Auto-fill food name from identified foods if still empty
      final foods = data['foods'] as List<dynamic>? ?? [];
      if (_foodName.text.isEmpty && foods.isNotEmpty) {
        _foodName.text = foods
            .map((f) => f['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
      }

      // Auto-fill calories if present and field is empty
      final totalCal = data['total_calories'];
      if (_calories.text.isEmpty && totalCal != null) {
        _calories.text = totalCal.toStringAsFixed(0);
      }

      setState(() => _nutrientResult = data);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = (e.response?.data is Map)
          ? e.response?.data['detail']?.toString() ?? 'Analysis failed'
          : 'Nutrient analysis unavailable';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _analyzingNutrients = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post('/foods', data: {
        'mealType': _mealType.text.trim(),
        'foodName': _foodName.text.trim(),
        'protein': double.tryParse(_protein.text) ?? 0,
        'carbs': double.tryParse(_carbs.text) ?? 0,
        'fats': double.tryParse(_fats.text) ?? 0,
        'calories': double.tryParse(_calories.text) ?? 0,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food log saved')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Save failed'
          : 'Save failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Food')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI Analyse section ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyse with AI',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _AiButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'Photo',
                          loading: _analyzingNutrients,
                          onTap: _analyzeFromPhoto,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AiButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          loading: _analyzingNutrients,
                          onTap: _analyzeFromGallery,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AiButton(
                          icon: Icons.edit_note_outlined,
                          label: 'Describe',
                          loading: _analyzingNutrients,
                          onTap: () => setState(
                            () => _showDescribeField = !_showDescribeField,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showDescribeField) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _describeController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'e.g. dal chawal with achar, 1 bowl',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _analyzingNutrients
                              ? null
                              : _analyzeFromDescription,
                          icon: _analyzingNutrients
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Nutrient breakdown card (shown after analysis) ──────────
          if (_nutrientResult != null)
            NutrientBreakdownCard(
              nutrients: _nutrientResult!['nutrients'] as Map<String, dynamic>? ?? {},
              foods: _nutrientResult!['foods'] as List<dynamic>? ?? [],
              confidenceNote: _nutrientResult!['confidence_note']?.toString(),
            ),

          const SizedBox(height: 12),

          // ── Manual entry form ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _field(_mealType, 'Meal type (e.g. lunch)'),
                  _field(_foodName, 'Food item'),
                  Row(
                    children: [
                      Expanded(child: _field(_protein, 'Protein (g)', type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_carbs, 'Carbs (g)', type: TextInputType.number)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _field(_fats, 'Fats (g)', type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_calories, 'Calories', type: TextInputType.number)),
                    ],
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surface,
                    title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Food Log'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}

class _AiButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _AiButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
