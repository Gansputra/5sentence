import 'sentence_pair.dart';

class Vocabulary {
  final int? id;
  final String word;
  final String meaning;
  final String category;
  final List<SentencePair> sentences;

  Vocabulary({
    this.id,
    required this.word,
    required this.meaning,
    required this.category,
    this.sentences = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word.toLowerCase(),
      'meaning': meaning,
      'category': category,
      'sentences': sentences.map((s) => s.toMap()).toList(),
    };
  }

  factory Vocabulary.fromMap(Map<String, dynamic> map) {
    return Vocabulary(
      id: map['id'],
      word: map['word'],
      meaning: map['meaning'],
      category: map['category'],
      sentences: (map['sentences'] as List?)
              ?.map((s) => SentencePair.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          [],
    );
  }
}
