import 'package:flutter_tts/flutter_tts.dart';

class AudioLabelService {
  AudioLabelService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1);
  }

  Future<void> speak(String label) async {
    await _tts.stop();
    await _tts.speak(label);
  }

  Future<void> dispose() => _tts.stop();
}
