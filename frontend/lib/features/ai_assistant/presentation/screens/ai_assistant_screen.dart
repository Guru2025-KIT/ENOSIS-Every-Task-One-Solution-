import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
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
      text: 'Hello! I am your ENOSIS AI Assistant. Ask me anything about your timetable, tasks, or attendance today.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  bool _isTyping = false;

  final List<String> _suggestions = [
    'What is my schedule today?',
    'Add a task to my list',
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Trigger mock response after delay
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
      if (!mounted) return;
      String response = '';

      final query = text.toLowerCase();
      if (query.contains('schedule') || query.contains('timetable') || query.contains('class')) {
        response = 'According to your timetable, your next lecture is "DAA Lecture" in Room 301 at 09:00 AM today.';
      } else if (query.contains('task') || query.contains('todo') || query.contains('list')) {
        response = 'Sure! I can help you with that. I have added "Review CO-PO attainment report" to your task list.';
      } else if (query.contains('attendance') || query.contains('percent') || query.contains('mark')) {
        response = 'Your average attendance rate is 96% (Present: 1708, Absent: 60, Leave: 20). You are fully compliant!';
      } else {
        response = 'I processed your query: "$text". Currently, I can help you fetch your timetable slots, add task reminders, or view attendance metrics.';
      }

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false, timestamp: DateTime.now()));
        _isTyping = false;
      });
      _scrollToBottom();
    });
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _ChatBubble(message: msg);
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
                    Text('Assistant is typing...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
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
                        onSubmitted: _sendMessage,
                        decoration: const InputDecoration(
                          hintText: 'Ask your assistant...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 24,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: () => _sendMessage(_textController.text),
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

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? AppColors.primary : AppColors.surface;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;
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
              border: message.isUser ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              message.text,
              style: AppTypography.bodyMedium.copyWith(color: textColor),
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
