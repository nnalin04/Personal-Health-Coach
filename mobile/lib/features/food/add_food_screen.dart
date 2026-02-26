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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Food log saved')));
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['message']?.toString() ?? 'Save failed')),
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
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Food')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field(_mealType, 'Meal Type'),
            _field(_foodName, 'Food Name'),
            _field(_protein, 'Protein (g)', keyboardType: TextInputType.number),
            _field(_carbs, 'Carbs (g)', keyboardType: TextInputType.number),
            _field(_fats, 'Fats (g)', keyboardType: TextInputType.number),
            _field(_calories, 'Calories', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
              title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child:
                  _loading ? const CircularProgressIndicator() : const Text('Save Food Log'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
