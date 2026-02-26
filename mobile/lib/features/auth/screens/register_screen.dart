import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();
  final _height = TextEditingController();
  final _goal = TextEditingController();
  final _dietType = TextEditingController();
  final _medicalFlags = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _age.dispose();
    _gender.dispose();
    _height.dispose();
    _goal.dispose();
    _dietType.dispose();
    _medicalFlags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await ref.read(authControllerProvider.notifier).register({
        'email': _email.text.trim(),
        'password': _password.text,
        'age': int.tryParse(_age.text) ?? 0,
        'gender': _gender.text.trim(),
        'height': double.tryParse(_height.text) ?? 0,
        'goal': _goal.text.trim(),
        'dietType': _dietType.text.trim(),
        'medicalFlags': _medicalFlags.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _field(_email, 'Email', TextInputType.emailAddress),
              _field(_password, 'Password', TextInputType.visiblePassword,
                  obscure: true),
              _field(_age, 'Age', TextInputType.number),
              _field(_gender, 'Gender', TextInputType.text),
              _field(_height, 'Height (cm)', TextInputType.number),
              _field(_goal, 'Goal', TextInputType.text),
              _field(_dietType, 'Diet Type', TextInputType.text),
              _field(_medicalFlags, 'Medical Flags', TextInputType.multiline),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.loading ? null : _submit,
                  child: state.loading
                      ? const CircularProgressIndicator()
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    TextInputType type, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Registration failed';
    }
    return 'Unexpected error';
  }
}
