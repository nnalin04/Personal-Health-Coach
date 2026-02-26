import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_provider.dart';

class UploadMedicalReportScreen extends ConsumerStatefulWidget {
  const UploadMedicalReportScreen({super.key});

  @override
  ConsumerState<UploadMedicalReportScreen> createState() => _UploadMedicalReportScreenState();
}

class _UploadMedicalReportScreenState extends ConsumerState<UploadMedicalReportScreen> {
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

      await ref.read(apiClientProvider).post(
            '/medical/reports',
            data: formData,
            isMultipart: true,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medical report uploaded and parsed')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['message']?.toString() ?? 'Upload failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Medical Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_present),
                title: Text(_selectedFile?.name ?? 'Select PDF/TXT report'),
                trailing: TextButton(onPressed: _pickFile, child: const Text('Choose')),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text('Report Date: ${DateFormat('yyyy-MM-dd').format(_reportDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _upload,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Upload and Parse'),
            ),
          ],
        ),
      ),
    );
  }
}
