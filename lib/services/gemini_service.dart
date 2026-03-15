import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/sentence_pair.dart';

class GeminiService {
  Future<List<SentencePair>> generateSentences(String word, String modelId) async {
    final apiKey = AppConstants.geminiApiKey;
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

    final prompt = '''
Generate exactly 5 different English sentences using the word: "$word".

Rules:
- The word must appear in every sentence.
- Provide a clear and natural Indonesian translation for each sentence.
- Return the result ONLY as a JSON array of objects with keys "en" and "id".
- Example format: [{"en": "Sentence", "id": "Terjemahan"}]
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
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 2048, // Increased for translations
          }
        }),
      );

      print('Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] == null || data['candidates'].isEmpty) {
           throw Exception('No candidates returned from Gemini. Body: ${response.body}');
        }

        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        print('Raw Text: $text');
        
        return _parseSentences(text);
      } else {
        throw Exception('API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('GeminiService Error: $e');
      rethrow;
    }
  }

  List<SentencePair> _parseSentences(String text) {
    try {
      // Find the JSON array in the text (sometimes AI adds markdown blocks)
      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception("Could not find JSON array in response");
      }
      
      final jsonPart = text.substring(jsonStart, jsonEnd);
      final List<dynamic> list = jsonDecode(jsonPart);
      
      return list.map((item) => SentencePair(
        english: item['en'] ?? '',
        indonesian: item['id'] ?? '',
      )).toList();
    } catch (e) {
      print('Parsing Error: $e');
      // Fallback: If JSON parsing fails, return empty list or handle differently
      throw Exception("Failed to parse AI response into sentences: $e");
    }
  }
}
