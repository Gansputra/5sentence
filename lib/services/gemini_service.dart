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
Also, extract up to 10 most interesting vocabulary words from those sentences with their Indonesian meanings and grammatical categories (Noun, Verb, etc.).

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
          if (repairedJson != null && repairedJson != cleanText) {
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

  /// Improved JSON repair: strips partial text and closes braces
  String? _repairTruncatedJson(String jsonStr) {
    String repaired = jsonStr.trim();
    
    // 1. Strip trailing partial property/value (anything after the last valid complete object/array element)
    // We look for the last comma or the start of the last object/array
    final lastComma = repaired.lastIndexOf(',');
    final lastOpenBrace = repaired.lastIndexOf('{');
    final lastOpenBracket = repaired.lastIndexOf('[');
    
    // If it looks like we're in the middle of a key-value pair, cut back to the last comma
    if (lastComma > lastOpenBrace && lastComma > lastOpenBracket) {
      repaired = repaired.substring(0, lastComma);
    } else if (lastOpenBrace > lastComma) {
      // We are inside an unfinished object, cut back to before this object if possible
      repaired = repaired.substring(0, lastOpenBrace).trim();
      if (repaired.endsWith(',')) repaired = repaired.substring(0, repaired.length - 1);
    }

    // 2. Count open/close delimiters
    int openBraces = '{'.allMatches(repaired).length;
    int closeBraces = '}'.allMatches(repaired).length;
    int openBrackets = '['.allMatches(repaired).length;
    int closeBrackets = ']'.allMatches(repaired).length;

    // 3. Close open brackets and braces
    while (openBrackets > closeBrackets) {
      repaired += ']';
      closeBrackets++;
    }
    while (openBraces > closeBraces) {
      repaired += '}';
      closeBraces++;
    }

    try {
      jsonDecode(repaired);
      return repaired;
    } catch (e) {
      print('Manual repair failed second pass: $e');
      // If still fails, try one more time by just closing whatever is open
      return _basicClose(jsonStr);
    }
  }

  String _basicClose(String jsonStr) {
    String repaired = jsonStr.trim();
    if (repaired.split('"').length % 2 == 0) repaired += '"';
    
    int openBraces = '{'.allMatches(repaired).length;
    int closeBraces = '}'.allMatches(repaired).length;
    int openBrackets = '['.allMatches(repaired).length;
    int closeBrackets = ']'.allMatches(repaired).length;

    while (openBrackets > closeBrackets) { repaired += ']'; closeBrackets++; }
    while (openBraces > closeBraces) { repaired += '}'; closeBraces++; }
    
    return repaired;
  }
}
