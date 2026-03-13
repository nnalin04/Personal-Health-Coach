import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum ChatAttachmentSource { camera, gallery, file }

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final Future<void> Function(ChatAttachmentSource source) onPickAttachment;
  final ValueChanged<String>? onQuickPrompt;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onPickAttachment,
    this.onQuickPrompt,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _speech = SpeechToText();
  bool _isTextEmpty = true;
  bool _speechReady = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _isTextEmpty = _controller.text.trim().isEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
    }

    if (!_speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission not granted')),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      partialResults: true,
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      },
    );
  }

  void _submit() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    widget.onSend(message);
    _controller.clear();
  }

  Future<void> _showAttachmentSheet() async {
    final choice = await showModalBottomSheet<ChatAttachmentSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ChatAttachmentSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ChatAttachmentSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF / File'),
              onTap: () => Navigator.pop(context, ChatAttachmentSource.file),
            ),
          ],
        ),
      ),
    );

    if (choice != null) {
      await widget.onPickAttachment(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Prompt Clips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PromptChip(
                  label: 'Log Meal',
                  icon: Icons.restaurant_rounded,
                  onTap: () => widget.onQuickPrompt?.call('I had a chicken salad for lunch'),
                ),
                _PromptChip(
                  label: 'Weight',
                  icon: Icons.monitor_weight_rounded,
                  onTap: () => widget.onQuickPrompt?.call('My weight is 75kg'),
                ),
                _PromptChip(
                  label: 'Check Stats',
                  icon: Icons.insights_rounded,
                  onTap: () => widget.onQuickPrompt?.call('Give me some insights'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Main Input Bar (Pill Shaped)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _showAttachmentSheet,
                  icon: Icon(Icons.add_rounded, color: theme.colorScheme.onSurfaceVariant, size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    onChanged: (val) => setState(() => _isTextEmpty = val.trim().isEmpty),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Ask VitalAI...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _toggleMic,
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isTextEmpty ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isTextEmpty ? theme.colorScheme.onSurface.withOpacity(0.1) : theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

