class Category {
  final String id;
  final String name;
  final String emoji;
  final int position;

  Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.position,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      emoji: map['emoji'],
      position: map['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'emoji': emoji, 'position': position};
  }

  Category copyWith({String? name, String? emoji, int? position}) {
    return Category(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      position: position ?? this.position,
    );
  }
}
