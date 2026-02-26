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
      appBar: AppBar(title: const Text('Add Body Metrics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field(_weight, 'Weight (kg)', keyboardType: TextInputType.number),
            _field(_bmi, 'BMI', keyboardType: TextInputType.number),
            _field(_bodyFat, 'Body Fat %', keyboardType: TextInputType.number),
            _field(_muscleMass, 'Muscle Mass (kg)', keyboardType: TextInputType.number),
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
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Save Body Metrics'),
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
