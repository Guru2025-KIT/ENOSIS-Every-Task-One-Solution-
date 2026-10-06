import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';

List<InlineSpan> _formatAssistantMessage(String text) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  final emphasis = RegExp(r'\*\*([^*\n]+)\*\*|\*([^*\n]+)\*');

  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final line = lines[lineIndex];
    final bullet = RegExp(r'^(\s*)[-*]\s+').firstMatch(line);
    final contentStart = bullet?.end ?? 0;
    if (bullet != null) {
      spans.add(TextSpan(text: '${bullet.group(1)}• '));
    }

    var cursor = contentStart;
    for (final match in emphasis.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      final boldText = match.group(1);
      final italicText = match.group(2);
      spans.add(TextSpan(
        text: boldText ?? italicText,
        style: boldText != null
            ? const TextStyle(fontWeight: FontWeight.bold)
            : const TextStyle(fontStyle: FontStyle.italic),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    if (lineIndex < lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }

  return spans;
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? retryText;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.retryText,
  });
}

/// Screen 17 — AI Assistant Chat UI.
///
/// Ref image features:
/// - Screen title "ENOSIS Assistant"
/// - Scrollable chat log
/// - Distinct incoming/outgoing message bubbles
/// - Quick action recommendation chips
/// - Bottom prompt input field with send button
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Hello! I am your ENOSIS Faculty Assistant. Ask me about your teaching schedule, assignments, or any general question.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  bool _isTyping = false;

  final List<String> _suggestions = [
    'What is my schedule today?',
    'What tasks are due soon?',
    'Show my attendance stats',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isTyping) return;

    final history = _messages
        .where((message) => message.retryText == null)
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed
        .map((message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            })
        .toList();

    setState(() {
      _messages.add(
          ChatMessage(text: prompt, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    var response = '';
    var retryText = '';
    try {
      final res = await ApiClient.postJson(
        '/ai/chat',
        {'message': prompt, 'conversation_history': history},
        timeoutSeconds: 35,
        retryOnTimeout: false,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic> || decoded['reply'] is! String) {
          throw const FormatException(
              'The assistant returned an invalid response.');
        }
        response = decoded['reply'] as String;
      } else {
        response = _errorMessage(res.body);
        retryText = prompt;
      }
    } on TimeoutException {
      response = 'The assistant took too long to respond. Please try again.';
      retryText = prompt;
    } on FormatException {
      response =
          'The assistant returned an invalid response. Please try again.';
      retryText = prompt;
    } catch (_) {
      response =
          'Could not connect to the ENOSIS assistant. Check your connection and try again.';
      retryText = prompt;
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          retryText: retryText.isEmpty ? null : retryText,
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      return 'The assistant could not answer right now. Please try again.';
    }
    return 'The assistant could not answer right now. Please try again.';
  }

  Future<void> _retryMessage(int index) async {
    if (_isTyping || index < 1 || index >= _messages.length) return;
    final failed = _messages[index];
    final prompt = failed.retryText;
    if (prompt == null) return;

    setState(() {
      _messages.removeAt(index);
      if (index > 0 &&
          _messages[index - 1].isUser &&
          _messages[index - 1].text == prompt) {
        _messages.removeAt(index - 1);
      }
    });
    await _sendMessage(prompt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ENOSIS Assistant'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Log
            Expanded(
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _ChatBubble(
                      message: msg,
                      onRetry: msg.retryText == null
                          ? null
                          : () => _retryMessage(index),
                    );
                  },
                ),
              ),
            ),

            // Typing indicator
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingIndicator(size: 24),
                    SizedBox(width: 10),
                    Text('Assistant is typing...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),

            // Suggestions chips
            if (!_isTyping)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary),
                      ),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.06),
                      onPressed: () => _sendMessage(suggestion),
                    );
                  },
                ),
              ),

            // Bottom Input Field
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) => _sendMessage(value),
                        decoration: const InputDecoration(
                          hintText: 'Ask your assistant...',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 24,
                      child: IconButton(
                        icon: const Icon(Icons.send,
                            color: Colors.white, size: 18),
                        onPressed: _isTyping
                            ? null
                            : () => _sendMessage(_textController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _ChatBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final align =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser
        ? AppColors.primary
        : onRetry != null
            ? AppColors.errorLight
            : AppColors.surface;
    final textColor = message.isUser
        ? Colors.white
        : onRetry != null
            ? AppColors.error
            : AppColors.textPrimary;
    final borderRadius = message.isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border:
                  message.isUser ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isUser)
                  Text(
                    message.text,
                    style: AppTypography.bodyMedium.copyWith(color: textColor),
                  )
                else
                  Text.rich(
                    TextSpan(
                      style:
                          AppTypography.bodyMedium.copyWith(color: textColor),
                      children: _formatAssistantMessage(message.text),
                    ),
                  ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try again'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
