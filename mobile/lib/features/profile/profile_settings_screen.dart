import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _apiBaseUrl = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();
  final _height = TextEditingController();
  final _goal = TextEditingController();
  final _dietType = TextEditingController();
  final _medicalFlags = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void dispose() {
    _apiBaseUrl.dispose();
    _age.dispose();
    _gender.dispose();
    _height.dispose();
    _goal.dispose();
    _dietType.dispose();
    _medicalFlags.dispose();
    super.dispose();
  }

  Future<void> _populate() async {
    _apiBaseUrl.text = ref.read(apiClientProvider).baseUrl;

    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      await ref.read(authControllerProvider.notifier).refreshUser();
    }
    final updatedUser = ref.read(authControllerProvider).user;
    if (updatedUser == null || !mounted) return;

    setState(() {
      _age.text = (updatedUser['age'] ?? '').toString();
      _gender.text = (updatedUser['gender'] ?? '').toString();
      _height.text = (updatedUser['height'] ?? '').toString();
      _goal.text = (updatedUser['goal'] ?? '').toString();
      _dietType.text = (updatedUser['dietType'] ?? '').toString();
      _medicalFlags.text = (updatedUser['medicalFlags'] ?? '').toString();
    });
  }

  Future<void> _save() async {
    final normalizedBaseUrl = _normalizeApiBaseUrl(_apiBaseUrl.text);
    if (normalizedBaseUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid API base URL')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(appConfigStorageProvider)
          .saveApiBaseUrl(normalizedBaseUrl);
      ref.read(apiClientProvider).setBaseUrl(normalizedBaseUrl);

      await ref.read(apiClientProvider).put('/users/me', data: {
        'age': int.tryParse(_age.text),
        'gender': _gender.text.trim(),
        'height': double.tryParse(_height.text),
        'goal': _goal.text.trim(),
        'dietType': _dietType.text.trim(),
        'medicalFlags': _medicalFlags.text.trim(),
      });
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile and connection updated')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                e.response?.data['message']?.toString() ?? 'Update failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Email'),
              subtitle: Text(authState.user?['email']?.toString() ?? '--'),
            ),
          ),
          _field(_age, 'Age', TextInputType.number),
          _field(_gender, 'Gender', TextInputType.text),
          _field(_height, 'Height (cm)', TextInputType.number),
          _field(_goal, 'Goal', TextInputType.text),
          _field(_dietType, 'Diet Type', TextInputType.text),
          _field(_medicalFlags, 'Medical Flags', TextInputType.multiline),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _field(
      TextEditingController controller, String label, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String? _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.isAbsolute || parsed.host.isEmpty) {
      return null;
    }

    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return null;
    }

    var normalized = trimmed;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
