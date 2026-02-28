import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';
import 'chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isUser: false,
      text:
          'I can log your health metrics from voice/text, upload medical files, and generate AI guidance from structured summaries.',
      time: DateTime.now(),
    ),
  ];

  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage(String text) async {
    _addMessage(_ChatMessage(isUser: true, text: text, time: DateTime.now()));

    // 1. Try AI-powered metric extraction first
    try {
      final extractionRes = await ref.read(apiClientProvider).post(
        '/extract-metrics',
        data: {'text': text},
      );
      
      final metricsData = extractionRes.data['metrics'] as List;
      if (metricsData.isNotEmpty) {
        for (final m in metricsData) {
          final metric = m['metric']?.toString().toLowerCase();
          final value = m['value'];
          final date = m['date'];
          
          String? endpoint;
          Map<String, dynamic> payload = {};
          String successMsg = '';

          if (metric == 'weight') {
            endpoint = '/body-metrics';
            payload = {'weight': value, 'date': date};
            successMsg = 'Logged weight: $value kg for $date.';
          } else if (metric == 'steps') {
            endpoint = '/steps';
            payload = {'stepCount': value.toInt(), 'date': date};
            successMsg = 'Logged steps: $value for $date.';
          } else if (metric == 'calories' || metric == 'food') {
            endpoint = '/foods';
            payload = {
              'foodName': 'Chat Entry',
              'calories': value,
              'mealType': 'Meal',
              'date': date,
            };
            successMsg = 'Logged $value kcal for $date.';
          }

          if (endpoint != null) {
            _addMessage(_ChatMessage(
              isUser: false,
              text: 'Detected $metric log. Saving...',
              time: DateTime.now(),
            ));
            await ref.read(apiClientProvider).post(endpoint, data: payload);
            _addMessage(_ChatMessage(isUser: false, text: successMsg, time: DateTime.now()));
          }
        }
        return;
      }
    } catch (e) {
      // Fallback to legacy regex if AI service is down or fails
      debugPrint('AI Extraction failed: $e');
    }

    // 2. Legacy Regex Parsers (Fallback)
    final action = _parseAction(text);
    if (action != null) {
      _addMessage(_ChatMessage(
        isUser: false,
        text: 'Detected ${action.label}. Saving...',
        time: DateTime.now(),
      ));
      await _applyAction(action);
      return;
    }

    if (_isInsightRequest(text)) {
      await _generateInsightsFromChat();
      return;
    }

    _addMessage(
      _ChatMessage(
        isUser: false,
        text: "I'm listening! You can log things like 'weight is 75kg' or 'walked 8000 steps'.",
        time: DateTime.now(),
      ),
    );
  }

  Future<void> _handleAttachment(ChatAttachmentSource source) async {
    try {
      String? path;
      String? filename;

      if (source == ChatAttachmentSource.camera) {
        final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (picked != null) {
          path = picked.path;
          filename = picked.name;
        }
      } else if (source == ChatAttachmentSource.gallery) {
        final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked != null) {
          path = picked.path;
          filename = picked.name;
        }
      } else {
        final file = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
          withData: false,
        );
        if (file != null && file.files.isNotEmpty) {
          final selected = file.files.first;
          path = selected.path;
          filename = selected.name;
        }
      }

      if (path == null || filename == null) return;

      _addMessage(
        _ChatMessage(
          isUser: true,
          text: 'Uploading file: $filename',
          time: DateTime.now(),
        ),
      );

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: filename),
        'reportDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      final response = await ref.read(apiClientProvider).post(
            '/medical/reports',
            data: formData,
            isMultipart: true,
          );

      final data = response.data;
      final notes = data is Map<String, dynamic>
          ? List<String>.from(data['extractionNotes'] ?? const [])
          : const <String>[];
      final note = notes.isNotEmpty ? '\nNotes: ${notes.join(' | ')}' : '';

      _addMessage(
        _ChatMessage(
          isUser: false,
          text: 'Medical report uploaded and parsed successfully.$note',
          time: DateTime.now(),
        ),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Attachment upload failed'
          : 'Attachment upload failed';
      _addMessage(
        _ChatMessage(
          isUser: false,
          text: message,
          time: DateTime.now(),
        ),
      );
    } catch (_) {
      _addMessage(
        _ChatMessage(
          isUser: false,
          text: 'Attachment upload failed',
          time: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _applyAction(_ParsedAction action) async {
    try {
      await ref.read(apiClientProvider).post(action.endpoint, data: action.payload);
      _addMessage(
        _ChatMessage(
          isUser: false,
          text: action.successMessage,
          time: DateTime.now(),
        ),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Unable to save log from chat input.'
          : 'Unable to save log from chat input.';
      _addMessage(
        _ChatMessage(
          isUser: false,
          text: message,
          time: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _generateInsightsFromChat() async {
    _addMessage(
      _ChatMessage(
        isUser: false,
        text: 'Generating recommendations from your latest health summary...',
        time: DateTime.now(),
      ),
    );

    try {
      final response = await ref.read(apiClientProvider).post('/health-summary/me/ai-insights');
      final root = Map<String, dynamic>.from(response.data as Map);
      final ai = Map<String, dynamic>.from(root['ai_insights'] as Map);

      String takeFirst(List<dynamic> values) {
        if (values.isEmpty) return '-';
        return values.take(2).join(' | ');
      }

      final text = [
        'Diet: ${takeFirst(List<dynamic>.from(ai['dietSuggestions'] ?? const []))}',
        'Training: ${takeFirst(List<dynamic>.from(ai['trainingSuggestions'] ?? const []))}',
        'Recovery: ${takeFirst(List<dynamic>.from(ai['recoverySuggestions'] ?? const []))}',
        'Medical awareness: ${takeFirst(List<dynamic>.from(ai['medicalAwarenessNotes'] ?? const []))}',
        ai['disclaimer']?.toString() ??
            'Informational only, not diagnosis.',
      ].join('\n\n');

      _addMessage(_ChatMessage(isUser: false, text: text, time: DateTime.now()));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString() ?? 'Unable to generate insights'
          : 'Unable to generate insights';
      _addMessage(_ChatMessage(isUser: false, text: message, time: DateTime.now()));
    }
  }

  bool _isInsightRequest(String text) {
    final lower = text.toLowerCase();
    return lower.contains('insight') ||
        lower.contains('recommend') ||
        lower.contains('suggest');
  }

  _ParsedAction? _parseAction(String text) {
    final lower = text.toLowerCase();
    final date = _extractDate(lower);
    final dateValue = DateFormat('yyyy-MM-dd').format(date);

    final weightMatch = RegExp(r'(?:weight(?:\s+is|\s+was)?|weigh(?:\s+in)?(?:\s+at)?)\s*(\d+(?:\.\d+)?)')
        .firstMatch(lower);
    if (weightMatch != null) {
      final weight = double.tryParse(weightMatch.group(1)!);
      if (weight != null) {
        return _ParsedAction(
          label: 'body weight: $weight kg on $dateValue',
          endpoint: '/body-metrics',
          payload: {
            'weight': weight,
            'bmi': null,
            'bodyFat': null,
            'muscleMass': null,
            'date': dateValue,
          },
          successMessage: 'Logged weight $weight kg for $dateValue.',
        );
      }
    }

    final stepsMatch = RegExp(r'(\d{3,6})\s*(?:steps|step)').firstMatch(lower);
    if (stepsMatch != null) {
      final steps = int.tryParse(stepsMatch.group(1)!);
      if (steps != null) {
        return _ParsedAction(
          label: 'steps: $steps on $dateValue',
          endpoint: '/steps',
          payload: {
            'stepCount': steps,
            'date': dateValue,
          },
          successMessage: 'Logged $steps steps for $dateValue.',
        );
      }
    }

    final workoutMatch = RegExp(
      r'(?:log\s*)?(?:workout|exercise|did)\s*([a-z\s]+?)\s*(?:sets?\s*(\d+))\s*(?:reps?\s*(\d+))(?:\s*(?:weight|at)?\s*(\d+(?:\.\d+)?))?',
    ).firstMatch(lower);
    if (workoutMatch != null) {
      final exercise = workoutMatch.group(1)?.trim();
      final sets = int.tryParse(workoutMatch.group(2) ?? '');
      final reps = int.tryParse(workoutMatch.group(3) ?? '');
      final weight = double.tryParse(workoutMatch.group(4) ?? '0') ?? 0;

      if (exercise != null && exercise.isNotEmpty && sets != null && reps != null) {
        return _ParsedAction(
          label: 'workout $exercise $sets x $reps',
          endpoint: '/workouts',
          payload: {
            'exerciseName': _titleCase(exercise),
            'sets': sets,
            'reps': reps,
            'weight': weight,
            'date': dateValue,
          },
          successMessage: 'Logged workout ${_titleCase(exercise)} ($sets x $reps) for $dateValue.',
        );
      }
    }

    if (lower.contains('log food') || lower.contains('ate ') || lower.contains('meal')) {
      final calories = _firstDouble(lower, [
            RegExp(r'calories?\s*(\d+(?:\.\d+)?)'),
            RegExp(r'(\d+(?:\.\d+)?)\s*kcal'),
          ]) ??
          0;
      final protein = _firstDouble(lower, [RegExp(r'protein\s*(\d+(?:\.\d+)?)')]) ?? 0;
      final carbs = _firstDouble(lower, [RegExp(r'carbs?\s*(\d+(?:\.\d+)?)')]) ?? 0;
      final fats = _firstDouble(lower, [RegExp(r'fat(?:s)?\s*(\d+(?:\.\d+)?)')]) ?? 0;

      final mealType = lower.contains('breakfast')
          ? 'Breakfast'
          : lower.contains('lunch')
              ? 'Lunch'
              : lower.contains('dinner')
                  ? 'Dinner'
                  : lower.contains('snack')
                      ? 'Snack'
                      : 'Meal';

      final foodName = _extractFoodName(text);
      if (foodName.isNotEmpty) {
        return _ParsedAction(
          label: '$mealType $foodName',
          endpoint: '/foods',
          payload: {
            'mealType': mealType,
            'foodName': foodName,
            'protein': protein,
            'carbs': carbs,
            'fats': fats,
            'calories': calories,
            'date': dateValue,
          },
          successMessage: 'Logged $mealType item "$foodName" for $dateValue.',
        );
      }
    }

    return null;
  }

  DateTime _extractDate(String text) {
    if (text.contains('yesterday')) {
      return DateTime.now().subtract(const Duration(days: 1));
    }

    final explicit = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (explicit != null) {
      final parsed = DateTime.tryParse(explicit.group(1)!);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  double? _firstDouble(String input, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) return value;
      }
    }
    return null;
  }

  String _extractFoodName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ate ')) {
      final start = lower.indexOf('ate ') + 4;
      var end = text.length;
      for (final stopper in [' protein', ' carbs', ' fat', ' calories', ' kcal']) {
        final idx = lower.indexOf(stopper, start);
        if (idx != -1) end = idx < end ? idx : end;
      }
      return text.substring(start, end).trim();
    }

    final cleaned = text
        .replaceAll(RegExp(r'log food', caseSensitive: false), '')
        .replaceAll(RegExp(r'breakfast|lunch|dinner|snack', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? 'Meal Entry' : cleaned;
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  void _addMessage(_ChatMessage message) {
    setState(() => _messages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 90,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VitalAI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Health Assistant',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment:
                        msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!msg.isUser)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 10),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                                child: Icon(Icons.smart_toy_rounded,
                                    size: 16, color: theme.colorScheme.primary),
                              ),
                            ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? theme.colorScheme.primary
                                    : (theme.brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: msg.isUser ? const Radius.circular(20) : Radius.zero,
                                  bottomRight: msg.isUser ? Radius.zero : const Radius.circular(20),
                                ),
                              ),
                              child: Text(
                                msg.text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: msg.isUser ? Colors.white : theme.colorScheme.onSurface,
                                  height: 1.4,
                                  fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (msg.actions != null && msg.actions!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 38, top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: msg.actions!.map((action) {
                              return GestureDetector(
                                onTap: () => _handleSendMessage(action),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4)),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    action,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          ChatInputBar(
            onSend: _handleSendMessage,
            onPickAttachment: _handleAttachment,
            onQuickPrompt: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final DateTime time;
  final List<String>? actions;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    required this.time,
    this.actions,
  });
}

class _ParsedAction {
  final String label;
  final String endpoint;
  final Map<String, dynamic> payload;
  final String successMessage;

  _ParsedAction({
    required this.label,
    required this.endpoint,
    required this.payload,
    required this.successMessage,
  });
}


