import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCaptureService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _stt.initialize(
        onError: (e) => debugPrint('STT Error: $e'),
        onStatus: (s) => debugPrint('STT Status: $s'),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('STT init exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> startListening({
    required Function(String words) onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return;
    }

    // Prefer Bengali locale 'bn_BD' if available
    final locales = await _stt.locales();
    var targetLocale = 'bn_BD';
    final hasBn = locales.any((l) => l.localeId.startsWith('bn'));
    if (!hasBn && locales.isNotEmpty) {
      targetLocale = locales.first.localeId;
    }

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: localeId ?? targetLocale,
    );
  }

  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }
}
