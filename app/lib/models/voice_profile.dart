class VoiceProfile {
  final String id;
  final String name;
  final String elevenLabsVoiceId;
  final String? samplePath;
  final int createdAt;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.elevenLabsVoiceId,
    this.samplePath,
    required this.createdAt,
  });

  factory VoiceProfile.fromMap(Map<String, dynamic> map) {
    return VoiceProfile(
      id: map['id'],
      name: map['name'],
      elevenLabsVoiceId: map['elevenlabs_voice_id'],
      samplePath: map['sample_path'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'elevenlabs_voice_id': elevenLabsVoiceId,
      'sample_path': samplePath,
      'created_at': createdAt,
    };
  }

  VoiceProfile copyWith({
    String? name,
    String? elevenLabsVoiceId,
    String? samplePath,
  }) {
    return VoiceProfile(
      id: id,
      name: name ?? this.name,
      elevenLabsVoiceId: elevenLabsVoiceId ?? this.elevenLabsVoiceId,
      samplePath: samplePath ?? this.samplePath,
      createdAt: createdAt,
    );
  }
}
