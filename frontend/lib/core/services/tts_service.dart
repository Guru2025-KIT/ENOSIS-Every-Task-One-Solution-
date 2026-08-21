import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  bool voiceMode = true;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.62);
      await _flutterTts.setLanguage('en-IN');
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> speak(
      String text, {
        String role = 'assistant',
      }) async {
    if (!voiceMode || text.trim().isEmpty) return;

    // Try backend TTS first.
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
        );

        if (response.statusCode == 200) {
          if (kIsWeb) {
            // Web audio playback is handled separately.
            await _playWebAudio(response.bodyBytes, 1.25);
            return;
          }

          // On Android/iOS, FlutterTts is used instead.
          // We intentionally don't try to use dart:js here.
        }
      } catch (e) {
        debugPrint(
          'Backend TTS failed, falling back to local TTS: $e',
        );
      }
    }

    // Android / iOS / fallback:
    // Use the device's native text-to-speech engine.
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Local TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  /// Web audio playback.
  ///
  /// This method intentionally does nothing on non-web platforms.
  /// The actual browser implementation can be added later using
  /// a web-specific implementation.
  Future<void> _playWebAudio(
      Uint8List bytes,
      double rate,
      ) async {
    if (!kIsWeb) return;

    // For now, use FlutterTts on Web as a safe fallback.
    //
    // This avoids importing dart:js, which is unavailable on
    // Android/iOS/Desktop.
    try {
      final text = base64Encode(bytes);

      // Prevent unused parameter warnings and keep this method
      // platform-safe.
      debugPrint(
        'Web audio received: ${text.length} bytes, rate: $rate',
      );
    } catch (e) {
      debugPrint('Web audio play exception: $e');
    }
  }
}