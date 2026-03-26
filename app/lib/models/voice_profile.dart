class VoiceProfile {
  final String id;
  final String name;
  final String voiceId;
  final String? samplePath;
  final int createdAt;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.voiceId,
    this.samplePath,
    required this.createdAt,
  });

  factory VoiceProfile.fromMap(Map<String, dynamic> map) {
    return VoiceProfile(
      id: map['id'],
      name: map['name'],
      voiceId: map['voice_id'],
      samplePath: map['sample_path'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'voice_id': voiceId,
      'sample_path': samplePath,
      'created_at': createdAt,
    };
  }

  VoiceProfile copyWith({
    String? name,
    String? voiceId,
    String? samplePath,
  }) {
    return VoiceProfile(
      id: id,
      name: name ?? this.name,
      voiceId: voiceId ?? this.voiceId,
      samplePath: samplePath ?? this.samplePath,
      createdAt: createdAt,
    );
  }
}
