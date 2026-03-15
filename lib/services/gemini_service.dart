import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/sentence_pair.dart';
import '../models/vocabulary.dart';
import '../models/gemini_response.dart';
import 'storage_service.dart';

class GeminiService {
  final StorageService _storageService = StorageService();

  Future<GeminiResponse> generateContent(String word, String modelId) async {
    String? apiKey = await _storageService.getActiveKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key is missing. Please go to Settings and enter your API Key.');
    }
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

    final prompt = '''
Create 5 English sentences with "$word" (with Indonesian translations).
Also, list every unique word from those sentences with its Indonesian meaning and category (Noun, Verb, Adjective, etc.).

Return ONLY a JSON with this structure:
{
  "sentences": [{"en": "...", "id": "..."}],
  "vocabulary": [{"word": "...", "meaning": "...", "category": "..."}]
}
''';

    print('Requesting Gemini with model: $modelId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1, // Lower temperature for more consistent JSON
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 4096,
            'responseMimeType': 'application/json', // Force JSON response
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || data['candidates'].isEmpty) {
           throw Exception('No candidates returned from Gemini.');
        }

        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        return _parseResponse(text);
      } else {
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('GeminiService Error: $e');
      rethrow;
    }
  }

  GeminiResponse _parseResponse(String text) {
    try {
      // Clean output just in case (though responseMimeType should handle it)
      final cleanText = text.trim();
      final Map<String, dynamic> data = jsonDecode(cleanText);
      
      final List<dynamic> sentenceList = data['sentences'] ?? [];
      final List<dynamic> vocabList = data['vocabulary'] ?? [];
      
      final sentences = sentenceList.map((item) => SentencePair(
        english: item['en'] ?? '',
        indonesian: item['id'] ?? '',
      )).toList();
      
      final vocabulary = vocabList.map((item) => Vocabulary(
        word: item['word'] ?? '',
        meaning: item['meaning'] ?? '',
        category: item['category'] ?? 'Common Word',
      )).toList();
      
      return GeminiResponse(sentences: sentences, vocabulary: vocabulary);
    } catch (e) {
      print('Parsing Error: $e. Raw text: $text');
      throw Exception("Failed to parse AI response: $e");
    }
  }
}
