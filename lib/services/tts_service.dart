import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive/hive.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  static const String _voiceKey = 'preferred_voice';

  Future<void> init() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Load saved voice if exists
    final box = Hive.box('settings_box');
    final savedVoice = box.get(_voiceKey);
    if (savedVoice != null) {
      // Structure of voice map: {"name": "...", "locale": "..."}
      await _flutterTts.setVoice(Map<String, String>.from(savedVoice));
    }
  }

  Future<List<dynamic>> getVoices() async {
    return await _flutterTts.getVoices;
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
    final box = Hive.box('settings_box');
    await box.put(_voiceKey, voice);
  }

  Future<Map<String, String>?> getSelectedVoice() async {
    final box = Hive.box('settings_box');
    final voice = box.get(_voiceKey);
    return voice != null ? Map<String, String>.from(voice) : null;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
