import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class GeminiService {
  Future<List<String>> generateSentences(String word, String modelId) async {
    final apiKey = AppConstants.geminiApiKey;
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');

    final prompt = '''
Generate exactly 5 different English sentences using the word: "$word".

Rules:
- The word must appear in every sentence.
- Sentences must be natural and easy to understand.
- Each sentence must be different.
- Return only the sentences in numbered format.
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
            'maxOutputTokens': 1024,
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

  List<String> _parseSentences(String text) {
    final lines = text.split('\n');
    final List<String> sentences = [];
    
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      final cleanLine = trimmed.replaceFirst(RegExp(r'^[\d\-\.\)]+\s*'), '');
      if (cleanLine.isNotEmpty) {
        sentences.add(cleanLine);
      }
    }
    
    return sentences.take(5).toList();
  }
}
