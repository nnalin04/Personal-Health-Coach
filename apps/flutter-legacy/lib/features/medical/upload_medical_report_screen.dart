import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

class UploadMedicalReportScreen extends ConsumerStatefulWidget {
  const UploadMedicalReportScreen({super.key});

  @override
  ConsumerState<UploadMedicalReportScreen> createState() =>
      _UploadMedicalReportScreenState();
}

class _UploadMedicalReportScreenState
    extends ConsumerState<UploadMedicalReportScreen> {
  PlatformFile? _selectedFile;
  DateTime _reportDate = DateTime.now();
  bool _loading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _reportDate,
    );
    if (date != null) {
      setState(() => _reportDate = date);
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null || _selectedFile!.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report file')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path!,
          filename: _selectedFile!.name,
        ),
        'reportDate': DateFormat('yyyy-MM-dd').format(_reportDate),
      });

      final response = await ref.read(apiClientProvider).post(
            '/medical/reports',
            data: formData,
            isMultipart: true,
          );

      if (!mounted) return;
      final data = response.data;
      final notes = data is Map<String, dynamic>
          ? List<String>.from(data['extractionNotes'] ?? const [])
          : const <String>[];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notes.isEmpty
                ? 'Report uploaded and parsed'
                : 'Report uploaded: ${notes.first}',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Upload failed'
          : 'Upload failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Medical Records'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.history_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Upload Report",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "VitalAI will automatically extract lab results and metrics from your medical documents.",
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          
          _UploadCard(
            title: _selectedFile?.name ?? 'Select document',
            subtitle: 'PDF, Images, or TXT reports',
            icon: Icons.upload_file_rounded,
            onTap: _pickFile,
            isSelected: _selectedFile != null,
          ),
          const SizedBox(height: 16),
          _UploadCard(
            title: 'Report Date: ${DateFormat('MMM d, yyyy').format(_reportDate)}',
            subtitle: 'This helps us track your progress',
            icon: Icons.calendar_today_rounded,
            onTap: _pickDate,
          ),
          
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _loading ? null : _upload,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: _loading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Upload & Extract', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _UploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(isSelected ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

