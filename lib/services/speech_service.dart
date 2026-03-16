import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;
    
    // Check and request microphone permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    
    if (status.isGranted) {
      _isInitialized = await _speech.initialize(
        onError: (val) => print('STT Error: $val'),
        onStatus: (val) => print('STT Status: $val'),
      );
      return _isInitialized;
    }
    return false;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(bool) onListeningStateChanged,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) return;
    }

    onListeningStateChanged(true);
    await _speech.listen(
      onResult: (val) {
        onResult(val.recognizedWords);
      },
      localeId: 'en_US', // Always listen for English
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  /// Calculates similarity between spoken text and target sentence (0.0 to 1.0)
  double getSimilarity(String spoken, String target) {
    if (spoken.isEmpty) return 0.0;
    
    // Cleanup: remove punctuation, lowercase
    String cleanSpoken = spoken.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    String cleanTarget = target.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    if (cleanSpoken == cleanTarget) return 1.0;
    
    List<String> spokenWords = cleanSpoken.split(' ');
    List<String> targetWords = cleanTarget.split(' ');
    
    int matchCount = 0;
    for (var word in spokenWords) {
      if (targetWords.contains(word)) {
        matchCount++;
      }
    }
    
    // Simple word match percentage
    double score = matchCount / targetWords.length;
    return score > 1.0 ? 1.0 : score;
  }
}
