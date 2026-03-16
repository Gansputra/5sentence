import 'sentence_pair.dart';

class Vocabulary {
  final int? id;
  final String word;
  final String ipa;
  final String meaning;
  final String meaningId;
  final String category;
  final List<SentencePair> sentences;

  Vocabulary({
    this.id,
    required this.word,
    required this.ipa,
    required this.meaning,
    required this.meaningId,
    required this.category,
    this.sentences = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word.toLowerCase(),
      'ipa': ipa,
      'meaning': meaning,
      'meaningId': meaningId,
      'category': category,
      'sentences': sentences.map((s) => s.toMap()).toList(),
    };
  }

  factory Vocabulary.fromMap(Map<String, dynamic> map) {
    return Vocabulary(
      id: map['id'],
      word: map['word'],
      ipa: map['ipa'] ?? '',
      meaning: map['meaning'],
      meaningId: map['meaningId'] ?? '',
      category: map['category'],
      sentences: (map['sentences'] as List?)
              ?.map((s) => SentencePair.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          [],
    );
  }
}
