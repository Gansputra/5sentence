import 'package:hive/hive.dart';
import '../models/vocabulary.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static const String _boxName = 'vocabulary_box';

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Box get _box => Hive.box(_boxName);

  Future<void> insertVocabulary(Vocabulary vocab) async {
    final word = vocab.word.toLowerCase();
    await _box.put(word, vocab.toMap());
  }

  Future<List<Vocabulary>> getAllVocabulary() async {
    final List<Vocabulary> list = _box.values.map((data) {
      final map = Map<String, dynamic>.from(data);
      return Vocabulary.fromMap(map);
    }).toList();
    
    // Sort by word
    list.sort((a, b) => a.word.compareTo(b.word));
    return list;
  }

  Future<void> deleteVocabularyByWord(String word) async {
    await _box.delete(word.toLowerCase());
  }

  Future<void> deleteVocabulary(int index) async {
    // Legacy support or fallback - better to use deleteVocabularyByWord
    final list = await getAllVocabulary();
    if (index >= 0 && index < list.length) {
      await deleteVocabularyByWord(list[index].word);
    }
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
