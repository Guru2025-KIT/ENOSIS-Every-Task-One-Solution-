import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';

List<InlineSpan> _formatAssistantMessage(String text, {Function(String url)? onUrlTap}) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  final emphasis = RegExp(r'\*\*([^*\n]+)\*\*|\*([^*\n]+)\*');
  final urlRegex = RegExp(r'(https?:\/\/[^\s\)\>]+)');

  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final line = lines[lineIndex];
    final bullet = RegExp(r'^(\s*)[-*•]\s+').firstMatch(line);
    final contentStart = bullet?.end ?? 0;
    if (bullet != null) {
      spans.add(TextSpan(text: '${bullet.group(1)}• '));
    }

    var cursor = contentStart;
    final matches = <_TextMatch>[];

    for (final match in emphasis.allMatches(line)) {
      if (match.start >= cursor) {
        matches.add(_TextMatch(
          start: match.start,
          end: match.end,
          text: match.group(1) ?? match.group(2) ?? '',
          isBold: match.group(1) != null,
          isItalic: match.group(2) != null,
        ));
      }
    }

    for (final match in urlRegex.allMatches(line)) {
      if (match.start >= cursor) {
        matches.add(_TextMatch(
          start: match.start,
          end: match.end,
          text: match.group(1) ?? '',
          isUrl: true,
        ));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, m.start)));
      }
      if (m.isUrl) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              if (onUrlTap != null) {
                onUrlTap(m.text);
              } else {
                _launchUrl(m.text);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'View Document',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: m.text,
          style: TextStyle(
            fontWeight: m.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: m.isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ));
      }
      cursor = m.end;
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

class _TextMatch {
  final int start;
  final int end;
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUrl;

  _TextMatch({
    required this.start,
    required this.end,
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUrl = false,
  });
}

Future<void> _launchUrl(String url) async {
  try {
    if (kIsWeb) {
      html.window.open(url, '_blank');
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Error launching URL: $e');
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? retryText;
  final bool isFromVoice;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.retryText,
    this.isFromVoice = false,
  });
}

/// AI Assistant Screen with Text & Voice (Speech-to-Text & ElevenLabs Text-to-Speech)
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Hello! I am your ENOSIS Assistant. You can type or tap the microphone to speak.\n\nAsk me about faculty schedules, career achievements, certificates, timetable assignments, or any general topic.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  bool _isTyping = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _currentSpeakingMessage = '';

  final List<String> _suggestions = [
    "What is my schedule today?",
    "Show faculty certificates & achievements",
    "What tasks are due soon?",
    "Show attendance summary",
    "What are the published timetable slots?",
    "Explain DBMS normalization",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ttsService.onSpeakingStarted = () {
      if (mounted) setState(() => _isSpeaking = true);
    };
    _ttsService.onSpeakingFinished = () {
      if (mounted) setState(() => _isSpeaking = false);
    };
  }

  @override
  void dispose() {
    _speechService.cancelListening();
    _ttsService.stop();
    _pulseController.dispose();
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

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speechService.stopListening();
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _sendMessage(_textController.text, fromVoice: true);
      }
      return;
    }

    await _ttsService.stop();
    _pulseController.repeat(reverse: true);
    setState(() => _isListening = true);

    await _speechService.startListening(
      onResult: (words) {
        if (mounted) {
          setState(() {
            _textController.text = words;
          });
        }
      },
      onComplete: () {
        if (mounted) {
          _pulseController.stop();
          _pulseController.reset();
          setState(() => _isListening = false);
          final spokenText = _textController.text.trim();
          if (spokenText.isNotEmpty) {
            _sendMessage(spokenText, fromVoice: true);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          _pulseController.stop();
          _pulseController.reset();
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking && _currentSpeakingMessage == text) {
      await _ttsService.stop();
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessage = '';
      });
      return;
    }

    setState(() {
      _currentSpeakingMessage = text;
      _isSpeaking = true;
    });

    // Clean markdown symbols for natural TTS speech
    final speechText = text
        .replaceAll(RegExp(r'\*\*|\*|#|-|•'), '')
        .replaceAll(RegExp(r'https?:\/\/[^\s]+'), 'link attached')
        .trim();

    await _ttsService.speak(speechText);
  }

  Future<void> _sendMessage(String text, {bool fromVoice = false}) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isTyping) return;

    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    }
    await _ttsService.stop();

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
        ChatMessage(
          text: prompt,
          isUser: true,
          timestamp: DateTime.now(),
          isFromVoice: fromVoice,
        ),
      );
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
          throw const FormatException('The assistant returned an invalid response.');
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
      response = 'The assistant returned an invalid response. Please try again.';
      retryText = prompt;
    } catch (_) {
      response = 'Could not connect to the ENOSIS assistant. Check your connection and try again.';
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

      // If queried via voice, automatically play voice response
      if (fromVoice && response.isNotEmpty && retryText.isEmpty) {
        _speakText(response);
      }
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
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFFF4791E)),
              tooltip: 'Stop speaking',
              onPressed: () => _ttsService.stop(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Active Voice/Speech State Banner
            if (_isListening)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFF4791E).withValues(alpha: 0.12),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4791E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Listening... Speak your command (e.g. "What is my schedule today?" or "Show certificates")',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF4791E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle, color: Color(0xFFF4791E)),
                      tooltip: 'Stop listening',
                      onPressed: _toggleVoiceInput,
                    ),
                  ],
                ),
              ),

            if (_isSpeaking && !_isListening)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primary.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Assistant is speaking response...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _ttsService.stop(),
                      icon: const Icon(Icons.stop, size: 16, color: AppColors.primary),
                      label: const Text('Stop Audio', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),

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
                    return _ChatBubble(
                      message: msg,
                      isSpeaking: _isSpeaking && _currentSpeakingMessage == msg.text,
                      onSpeak: () => _speakText(msg.text),
                      onRetry: msg.retryText == null ? null : () => _retryMessage(index),
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
                    LoadingIndicator(size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Assistant is analyzing data...',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

            // Suggestions chips
            if (!_isTyping && !_isListening)
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
                      avatar: const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.primary),
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

            // Bottom Input Field (Text + Voice Microphone)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    // Microphone Voice Input Button
                    Material(
                      color: _isListening ? const Color(0xFFF4791E) : AppColors.surfaceVariant,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isTyping ? null : _toggleVoiceInput,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.white : AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) => _sendMessage(value),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening to your voice...' : 'Type or ask a voice command...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: _isListening ? const Color(0xFFF4791E) : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Send Button
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 22,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _isTyping ? null : () => _sendMessage(_textController.text),
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
  final bool isSpeaking;
  final VoidCallback onSpeak;
  final VoidCallback? onRetry;

  const _ChatBubble({
    required this.message,
    required this.isSpeaking,
    required this.onSpeak,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
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
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border: message.isUser ? null : Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isUser)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isFromVoice) ...[
                        const Icon(Icons.mic, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          message.text,
                          style: AppTypography.bodyMedium.copyWith(color: textColor),
                        ),
                      ),
                    ],
                  )
                else
                  Text.rich(
                    TextSpan(
                      style: AppTypography.bodyMedium.copyWith(color: textColor),
                      children: _formatAssistantMessage(message.text),
                    ),
                  ),

                // Audio Listen / Speak Button for Assistant responses
                if (!message.isUser && onRetry == null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onSpeak,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSpeaking
                            ? const Color(0xFFF4791E).withValues(alpha: 0.12)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking ? Icons.volume_up : Icons.volume_down,
                            size: 14,
                            color: isSpeaking ? const Color(0xFFF4791E) : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSpeaking ? 'Speaking...' : 'Listen',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSpeaking ? const Color(0xFFF4791E) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try again'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
