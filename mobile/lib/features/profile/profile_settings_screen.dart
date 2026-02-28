import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
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

    var user = ref.read(authControllerProvider).user;
    if (user == null) {
      await ref.read(authControllerProvider.notifier).refreshUser();
      user = ref.read(authControllerProvider).user;
    }
    if (user == null || !mounted) return;

    setState(() {
      _age.text = (user!['age'] ?? '').toString();
      _gender.text = (user['gender'] ?? '').toString();
      _height.text = (user['height'] ?? '').toString();
      _goal.text = (user['goal'] ?? '').toString();
      _dietType.text = (user['dietType'] ?? '').toString();
      _medicalFlags.text = (user['medicalFlags'] ?? '').toString();
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
      await ref.read(appConfigStorageProvider).saveApiBaseUrl(normalizedBaseUrl);
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
        const SnackBar(content: Text('Profile updated')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Update failed'
          : 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    (authState.user?['email']?.toString().isNotEmpty ?? false)
                        ? authState.user!['email'].toString().substring(0, 1).toUpperCase()
                        : 'U',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authState.user?['email']?.toString() ?? '--',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('Connection'),
        _field(_apiBaseUrl, 'API Base URL (Dev/UAT/Prod)'),
        const _SectionTitle('Personal'),
        _field(_age, 'Age', type: TextInputType.number),
        _field(_gender, 'Gender'),
        _field(_height, 'Height (cm)', type: TextInputType.number),
        _field(_goal, 'Goal'),
        _field(_dietType, 'Diet Type'),
        _field(_medicalFlags, 'Medical Flags', type: TextInputType.multiline, maxLines: 3),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: label),
      ),
    );
  }

  String? _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.isAbsolute || parsed.host.isEmpty) return null;
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;

    var normalized = trimmed;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
