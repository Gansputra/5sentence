class SentencePair {
  final String english;
  final String indonesian;
  bool isTranslated;

  SentencePair({
    required this.english,
    required this.indonesian,
    this.isTranslated = false,
  });
}
