import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

class AddStepsScreen extends ConsumerStatefulWidget {
  const AddStepsScreen({super.key});

  @override
  ConsumerState<AddStepsScreen> createState() => _AddStepsScreenState();
}

class _AddStepsScreenState extends ConsumerState<AddStepsScreen> {
  final _steps = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post('/steps', data: {
        'stepCount': int.tryParse(_steps.text) ?? 0,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Steps saved')));
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
      appBar: AppBar(title: const Text('Log Steps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _steps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Step count'),
                  ),
                  const SizedBox(height: 10),
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
                : const Text('Save Steps'),
          ),
        ],
      ),
    );
  }
}
