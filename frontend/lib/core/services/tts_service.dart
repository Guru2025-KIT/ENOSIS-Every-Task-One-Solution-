import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:universal_html/html.dart' as html;

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  bool voiceMode = true;
  bool _isSpeaking = false;
  html.AudioElement? _currentWebAudio;

  bool get isSpeaking => _isSpeaking;

  VoidCallback? onSpeakingStarted;
  VoidCallback? onSpeakingFinished;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.55);
      await _flutterTts.setLanguage('en-IN');

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingStarted?.call();
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingFinished?.call();
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeakingFinished?.call();
      });
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        onSpeakingFinished?.call();
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> speak(
    String text, {
    String role = 'assistant',
  }) async {
    if (text.trim().isEmpty) return;
    await stop();

    _isSpeaking = true;
    onSpeakingStarted?.call();

    // 1. Try backend ElevenLabs / Neural TTS first
    if (AuthSession.token != null) {
      try {
        final body = {
          'text': text,
          'role': role,
        };

        final response = await ApiClient.postJson(
          '/voice/tts',
          body,
          token: AuthSession.token,
          timeoutSeconds: 15,
        );

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          if (kIsWeb) {
            await _playWebAudio(response.bodyBytes, 1.0, fallbackText: text);
            return;
          }
        }
      } catch (e) {
        debugPrint('Backend ElevenLabs TTS failed, falling back to local TTS: $e');
      }
    }

    // 2. Local fallback using FlutterTts
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Local TTS speak error: $e');
      _isSpeaking = false;
      onSpeakingFinished?.call();
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      if (kIsWeb && _currentWebAudio != null) {
        _currentWebAudio?.pause();
        _currentWebAudio = null;
      }
      await _flutterTts.stop();
    } catch (_) {}
    onSpeakingFinished?.call();
  }

  Future<void> _playWebAudio(Uint8List bytes, double rate, {String? fallbackText}) async {
    if (!kIsWeb) return;
    try {
      if (_currentWebAudio != null) {
        _currentWebAudio?.pause();
        _currentWebAudio = null;
      }
      final blob = html.Blob([bytes], 'audio/mpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final audio = html.AudioElement();
      audio.src = url;
      _currentWebAudio = audio;

      audio.onEnded.listen((_) {
        _isSpeaking = false;
        _currentWebAudio = null;
        onSpeakingFinished?.call();
      });
      audio.onError.listen((_) {
        _isSpeaking = false;
        _currentWebAudio = null;
        onSpeakingFinished?.call();
      });

      await audio.play();
    } catch (e) {
      debugPrint('Web audio play exception: $e');
      _isSpeaking = false;
      onSpeakingFinished?.call();
      if (fallbackText != null && fallbackText.isNotEmpty) {
        await _flutterTts.speak(fallbackText);
      }
    }
  }
}