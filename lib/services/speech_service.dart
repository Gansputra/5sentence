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
      try {
        _isInitialized = await _speech.initialize(
          onError: (val) => print('STT Error: ${val.errorMsg} - ${val.permanent}'),
          onStatus: (val) => print('STT Status: $val'),
        );
        if (!_isInitialized) {
          print('STT could not be initialized. Is Google app installed/updated?');
        }
        return _isInitialized;
      } catch (e) {
        print('STT Init Exception: $e');
        return false;
      }
    }
    print('Microphone permission denied');
    return false;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(bool) onListeningStateChanged,
  }) async {
    final bool available = await _speech.initialize();
    if (!available) {
      print('Speech recognition is not available on this device');
      onListeningStateChanged(false);
      return;
    }

    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        onListeningStateChanged(false);
        return;
      }
    }

    onListeningStateChanged(true);
    
    // Get available locales and try to find English
    List<stt.LocaleName> locales = await _speech.locales();
    stt.LocaleName? englishLocale;
    try {
      englishLocale = locales.firstWhere((local) => local.localeId.contains('en'));
    } catch (_) {
      // Fallback to system locale if English not found
    }

    await _speech.listen(
      onResult: (val) {
        onResult(val.recognizedWords);
      },
      localeId: englishLocale?.localeId ?? 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
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
