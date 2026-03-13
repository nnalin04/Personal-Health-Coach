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
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _medicalFlags = TextEditingController();

  String _gender = 'Male';
  String _goal = 'Muscle Gain';
  String _dietType = 'Balanced';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _medicalFlags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await ref.read(authControllerProvider.notifier).register({
        'email': _email.text.trim(),
        'password': _password.text,
        'name': _name.text.trim(),
        'age': int.tryParse(_age.text) ?? 0,
        'gender': _gender,
        'height': double.tryParse(_height.text) ?? 0,
        'weight': double.tryParse(_weight.text) ?? 0,
        'goal': _goal,
        'dietType': _dietType,
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          IconButton(
            onPressed: state.loading ? null : _submit,
            icon: state.loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            children: [
              // Avatar Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 64,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
                          backgroundImage: const NetworkImage('https://i.pravatar.cc/150?u=alex'),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _name.text.isEmpty ? 'New User' : _name.text,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 24),
                    ),
                    Text(
                      'VitalAI Member since Feb 2026',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              _SectionHeader(icon: Icons.person_rounded, title: 'Personal Information'),
              const SizedBox(height: 12),
              _field(_name, 'Full Name', icon: Icons.badge_outlined),
              _field(_email, 'Email Address', icon: Icons.email_outlined),
              _field(_password, 'Password', obscure: true, icon: Icons.lock_outline_rounded),
              
              Row(
                children: [
                  Expanded(child: _field(_age, 'Age', type: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _dropdown<String>(
                      value: _gender,
                      values: const ['Male', 'Female', 'Other'],
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(child: _field(_height, 'Height (cm)', type: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _dropdown<String>(
                      value: _goal,
                      values: const ['Muscle Gain', 'Weight Loss', 'Maintenance'],
                      onChanged: (v) => setState(() => _goal = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.restaurant_rounded, title: 'Health & Diet'),
              const SizedBox(height: 12),
              _dropdown<String>(
                value: _dietType,
                values: const ['Balanced', 'High Protein', 'Keto', 'Vegan'],
                onChanged: (v) => setState(() => _dietType = v!),
              ),
              TextField(
                controller: _medicalFlags,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Enter any medical conditions or allergies...',
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> values,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        items: values
            .map((v) => DropdownMenuItem<T>(
                  value: v,
                  child: Text(v.toString()),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Action failed';
    }
    return 'Unexpected error';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}


