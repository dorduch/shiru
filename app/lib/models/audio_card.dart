class AudioCard {
  final String id;
  final String? collectionId;
  final String title;
  final String color;
  final String? spriteKey;
  final String? customImagePath;
  final String audioPath;
  final int playbackPosition;
  final int position;
  final int createdAt;

  AudioCard({
    required this.id,
    this.collectionId,
    required this.title,
    required this.color,
    this.spriteKey,
    this.customImagePath,
    required this.audioPath,
    this.playbackPosition = 0,
    required this.position,
    required this.createdAt,
  });

  factory AudioCard.fromMap(Map<String, dynamic> map) {
    return AudioCard(
      id: map['id'],
      collectionId: map['collection_id'],
      title: map['title'],
      color: map['color'],
      spriteKey: map['sprite_key'],
      customImagePath: map['custom_image_path'],
      audioPath: map['audio_path'],
      playbackPosition: map['playback_position'] ?? 0,
      position: map['position'] ?? 0,
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'title': title,
      'color': color,
      'sprite_key': spriteKey,
      'custom_image_path': customImagePath,
      'audio_path': audioPath,
      'playback_position': playbackPosition,
      'position': position,
      'created_at': createdAt,
    };
  }

  AudioCard copyWith({
    String? collectionId,
    bool clearCollectionId = false,
    String? title,
    String? color,
    String? spriteKey,
    String? customImagePath,
    String? audioPath,
    int? playbackPosition,
    int? position,
  }) {
    return AudioCard(
      id: id,
      collectionId: clearCollectionId
          ? null
          : (collectionId ?? this.collectionId),
      title: title ?? this.title,
      color: color ?? this.color,
      spriteKey: spriteKey ?? this.spriteKey,
      customImagePath: customImagePath ?? this.customImagePath,
      audioPath: audioPath ?? this.audioPath,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      position: position ?? this.position,
      createdAt: createdAt,
    );
  }
}
