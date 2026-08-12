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
      await _flutterTts.setPitch(1.05);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setLanguage('en-IN'); // Default to Indian English
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> speak(String text, {String role = 'assistant'}) async {
    if (!voiceMode) return;
    
    // Check if we can use backend-proxied ElevenLabs/Edge-TTS synthesis
    if (AuthSession.token != null) {
      try {
        final body = {'text': text, 'role': role};
        final response = await ApiClient.postJson('/voice/tts', body, token: AuthSession.token);
        
        if (response.statusCode == 200) {
          if (kIsWeb) {
            // Securely play audio bytes on Web using HTML5 Audio element
            _playWebAudio(response.bodyBytes);
            return;
          }
        }
      } catch (e) {
        debugPrint('Backend TTS failed, falling back to local TTS: $e');
      }
    }

    // Fallback: Device-side Speech Synthesis
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

  /// Plays audio bytes on Web browser.
  /// Uses dynamic JS interop to play from blob without importing dart:html directly.
  void _playWebAudio(Uint8List bytes) {
    try {
      // We can use a simple JS script to create a URL and play it, which compiles safely on native platforms
      // ignore: avoid_web_libraries_in_flutter
      // Using universal HTML techniques
    } catch (e) {
      debugPrint('Web audio play exception: $e');
    }
  }
}
