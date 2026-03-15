class ApiKey {
  final String id;
  final String name;
  final String key;
  final bool isActive;

  ApiKey({
    required this.id,
    required this.name,
    required this.key,
    this.isActive = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'key': key,
      'isActive': isActive,
    };
  }

  factory ApiKey.fromMap(Map<String, dynamic> map) {
    return ApiKey(
      id: map['id'],
      name: map['name'],
      key: map['key'],
      isActive: map['isActive'] ?? false,
    );
  }

  ApiKey copyWith({bool? isActive, String? name, String? key}) {
    return ApiKey(
      id: id,
      name: name ?? this.name,
      key: key ?? this.key,
      isActive: isActive ?? this.isActive,
    );
  }
}
