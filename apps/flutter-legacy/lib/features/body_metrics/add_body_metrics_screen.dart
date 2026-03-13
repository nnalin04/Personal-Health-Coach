import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

class AddBodyMetricsScreen extends ConsumerStatefulWidget {
  const AddBodyMetricsScreen({super.key});

  @override
  ConsumerState<AddBodyMetricsScreen> createState() => _AddBodyMetricsScreenState();
}

class _AddBodyMetricsScreenState extends ConsumerState<AddBodyMetricsScreen> {
  final _weight = TextEditingController();
  final _bmi = TextEditingController();
  final _bodyFat = TextEditingController();
  final _muscleMass = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _weight.dispose();
    _bmi.dispose();
    _bodyFat.dispose();
    _muscleMass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post('/body-metrics', data: {
        'weight': double.tryParse(_weight.text) ?? 0,
        'bmi': double.tryParse(_bmi.text),
        'bodyFat': double.tryParse(_bodyFat.text),
        'muscleMass': double.tryParse(_muscleMass.text),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body metrics saved')),
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
      appBar: AppBar(title: const Text('Log Body Metrics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _field(_weight, 'Weight (kg)', type: TextInputType.number),
                  Row(
                    children: [
                      Expanded(child: _field(_bmi, 'BMI', type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_bodyFat, 'Body Fat (%)', type: TextInputType.number)),
                    ],
                  ),
                  _field(_muscleMass, 'Muscle Mass (kg)', type: TextInputType.number),
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
                : const Text('Save Metrics'),
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
