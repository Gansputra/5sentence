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
      throw Exception(
        'Gemini API Key is missing. Please go to Settings and enter your API Key.',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey',
    );

    final prompt =
        '''
Create exactly 5 English sentences using the word "$word" and provide their Indonesian translations.
Also, extract all unique vocabulary words from those sentences with their Indonesian meanings and grammatical categories (Noun, Verb, etc.).

Return the data STRICTLY as a JSON object with this exact structure:
{
  "sentences": [
    {"en": "Sentence in English", "id": "Terjemahan Bahasa Indonesia"}
  ],
  "vocabulary": [
    {"word": "Word", "meaning": "Arti", "category": "Category"}
  ]
}

IMPORTANT: Ensure the JSON is complete and valid. Do not include any text before or after the JSON.
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
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 4096,
            'responseMimeType': 'application/json',
            'responseSchema': {
              'type': 'object',
              'properties': {
                'sentences': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'en': {'type': 'string'},
                      'id': {'type': 'string'},
                    },
                    'required': ['en', 'id'],
                  },
                },
                'vocabulary': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'word': {'type': 'string'},
                      'meaning': {'type': 'string'},
                      'category': {'type': 'string'},
                    },
                    'required': ['word', 'meaning', 'category'],
                  },
                },
              },
              'required': ['sentences', 'vocabulary'],
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw Exception('No candidates returned from Gemini.');
        }

        final String text =
            data['candidates'][0]['content']['parts'][0]['text'];
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
    String cleanText = text.trim();

    // 1. Robust JSON Extraction: Handle potential markdown code blocks
    if (cleanText.contains('```')) {
      final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = regex.firstMatch(cleanText);
      if (match != null) {
        cleanText = match.group(1)!.trim();
      }
    }

    try {
      // 2. Pre-parsing Cleanup: Fix common trailing comma issues
      cleanText = cleanText.replaceAll(RegExp(r',\s*([\]}])'), r'$1');

      final Map<String, dynamic> data = jsonDecode(cleanText);

      final List<dynamic> sentenceList = data['sentences'] ?? [];
      final List<dynamic> vocabList = data['vocabulary'] ?? [];

      final sentences = sentenceList
          .map((item) {
            if (item is! Map) return SentencePair(english: '', indonesian: '');
            return SentencePair(
              english: item['en']?.toString() ?? '',
              indonesian: item['id']?.toString() ?? '',
            );
          })
          .where((s) => s.english.isNotEmpty)
          .toList();

      final vocabulary = vocabList
          .map((item) {
            if (item is! Map)
              return Vocabulary(word: '', meaning: '', category: '');
            return Vocabulary(
              word: item['word']?.toString() ?? '',
              meaning: item['meaning']?.toString() ?? '',
              category: item['category']?.toString() ?? 'Common Word',
            );
          })
          .where((v) => v.word.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        throw Exception("Gemini returned an empty list of sentences.");
      }

      return GeminiResponse(sentences: sentences, vocabulary: vocabulary);
    } catch (e) {
      print('Parsing Error: $e. Raw text: $text');

      // 3. Last Resort: Try to "repair" truncated JSON if it looks like it's cut off
      if (e is FormatException &&
          (cleanText.endsWith('"') ||
              cleanText.endsWith(':') ||
              cleanText.endsWith(',') ||
              !cleanText.endsWith('}'))) {
        try {
          final repairedJson = _repairTruncatedJson(cleanText);
          if (repairedJson != null) {
            print('Attempting to parse repaired JSON...');
            return _parseResponse(repairedJson);
          }
        } catch (repairError) {
          print('Repair failed: $repairError');
        }
      }

      throw Exception("Failed to parse AI response. Please try again.");
    }
  }

  /// Extremely simple JSON repair for common truncation scenarios
  String? _repairTruncatedJson(String jsonStr) {
    // Count open/close delimiters
    int openBraces = '{'.allMatches(jsonStr).length;
    int closeBraces = '}'.allMatches(jsonStr).length;
    int openBrackets = '['.allMatches(jsonStr).length;
    int closeBrackets = ']'.allMatches(jsonStr).length;

    String repaired = jsonStr.trim();

    // If it ends mid-key or mid-value, try to close the quote
    if (repaired.split('"').length % 2 == 0) {
      repaired += '"';
    }

    // Close objects and arrays in reverse order
    while (openBrackets > closeBrackets) {
      repaired += '}]'; // Attempt to close current item then array
      closeBrackets++;
      closeBraces++; // Assuming inside an object inside array
    }

    while (openBraces > closeBraces) {
      repaired += '}';
      closeBraces++;
    }

    try {
      jsonDecode(repaired);
      return repaired;
    } catch (_) {
      return null;
    }
  }
}
