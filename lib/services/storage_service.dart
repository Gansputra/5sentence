import 'package:hive/hive.dart';
import '../models/api_key_model.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static const String _boxName = 'api_keys_box';
  static const String _settingsBox = 'settings_box';
  static const String _themeKey = 'preferred_theme';
  final _uuid = const Uuid();

  factory StorageService() => _instance;

  StorageService._internal();

  Box get _box => Hive.box(_boxName);

  Future<void> saveApiKey(String key, {String? name}) async {
    final newKey = ApiKey(
      id: _uuid.v4(),
      name: name ?? "Key ${DateTime.now().millisecond}",
      key: key,
      isActive: _box.isEmpty, // Make active if it's the only one
    );
    await _box.put(newKey.id, newKey.toMap());
  }

  Future<List<ApiKey>> getAllApiKeys() async {
    return _box.values.map((v) => ApiKey.fromMap(Map<String, dynamic>.from(v))).toList();
  }

  Future<String?> getActiveKey() async {
    final keys = await getAllApiKeys();
    try {
      return keys.firstWhere((k) => k.isActive).key;
    } catch (_) {
      return keys.isNotEmpty ? keys.first.key : null;
    }
  }

  Future<void> setActiveKey(String id) async {
    final keys = await getAllApiKeys();
    for (var k in keys) {
      final updated = k.copyWith(isActive: k.id == id);
      await _box.put(updated.id, updated.toMap());
    }
  }

  Future<void> deleteKey(String id) async {
    await _box.delete(id);
  }

  // Theme support
  Future<void> setTheme(String themeName) async {
    final box = Hive.box(_settingsBox);
    await box.put(_themeKey, themeName);
  }

  Future<String> getTheme() async {
    final box = Hive.box(_settingsBox);
    return box.get(_themeKey, defaultValue: 'Teal');
  }
}
