import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

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
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _mealType.dispose();
    _foodName.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    _calories.dispose();
    super.dispose();
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _field(_mealType, 'Meal type'),
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
