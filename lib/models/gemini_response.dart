import '../models/sentence_pair.dart';
import '../models/vocabulary.dart';

class GeminiResponse {
  final List<SentencePair> sentences;
  final List<Vocabulary> vocabulary;

  GeminiResponse({
    required this.sentences,
    required this.vocabulary,
  });
}
