class SentencePair {
  final String english;
  final String indonesian;
  bool isTranslated;

  SentencePair({
    required this.english,
    required this.indonesian,
    this.isTranslated = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'en': english,
      'id': indonesian,
    };
  }

  factory SentencePair.fromMap(Map<String, dynamic> map) {
    return SentencePair(
      english: map['en'] ?? '',
      indonesian: map['id'] ?? '',
    );
  }
}
