enum CardMediaType { audio, video }

class AudioCard {
  final String id;
  final String? collectionId;
  final String title;
  final String color;
  final String? spriteKey;
  final String? customImagePath;
  final String audioPath;
  final CardMediaType mediaType;
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
    this.mediaType = CardMediaType.audio,
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
      mediaType: CardMediaType.values.firstWhere(
        (type) => type.name == map['media_type'],
        orElse: () => CardMediaType.audio,
      ),
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
      'media_type': mediaType.name,
      'playback_position': playbackPosition,
      'position': position,
      'created_at': createdAt,
    };
  }

  /// Neutral alias for [audioPath] while the persisted column remains
  /// `audio_path` for backwards compatibility.
  String get mediaPath => audioPath;

  AudioCard copyWith({
    String? collectionId,
    bool clearCollectionId = false,
    String? title,
    String? color,
    String? spriteKey,
    String? customImagePath,
    String? audioPath,
    CardMediaType? mediaType,
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
      mediaType: mediaType ?? this.mediaType,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      position: position ?? this.position,
      createdAt: createdAt,
    );
  }
}
