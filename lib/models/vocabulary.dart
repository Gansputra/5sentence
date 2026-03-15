class Vocabulary {
  final int? id;
  final String word;
  final String meaning;
  final String category;

  Vocabulary({
    this.id,
    required this.word,
    required this.meaning,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word.toLowerCase(),
      'meaning': meaning,
      'category': category,
    };
  }

  factory Vocabulary.fromMap(Map<String, dynamic> map) {
    return Vocabulary(
      id: map['id'],
      word: map['word'],
      meaning: map['meaning'],
      category: map['category'],
    );
  }
}
