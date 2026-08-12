import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

enum SpeechState { idle, listening, processing, success, error }

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  SpeechState _state = SpeechState.idle;
  
  SpeechState get state => _state;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        // Web Speech API does not require permission_handler permission checks
        return await _speech.initialize(
          onError: (val) => debugPrint('STT Error: $val'),
          onStatus: (val) => debugPrint('STT Status: $val'),
        );
      }

      // Android/iOS permission request
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        return await _speech.initialize(
          onError: (val) => debugPrint('STT Error: $val'),
          onStatus: (val) => debugPrint('STT Status: $val'),
        );
      }
      return false;
    } catch (e) {
      debugPrint('Speech initialization exception: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required VoidCallback onComplete,
    required Function(String error) onError,
  }) async {
    _state = SpeechState.listening;
    bool available = await initialize();
    if (!available) {
      _state = SpeechState.error;
      onError('Microphone permission denied or speech recognition unavailable.');
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _state = SpeechState.success;
            onResult(result.recognizedWords);
            onComplete();
          } else {
            // Interim/partial result
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_IN', // Default to Indian English for natural accent parsing
        listenOptions: stt.SpeechListenOptions(cancelOnError: true),
      );
    } catch (e) {
      _state = SpeechState.error;
      onError('Failed to start listening: $e');
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      _state = SpeechState.idle;
    }
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    _state = SpeechState.idle;
  }
}
