class VoiceProfile {
  final String id;
  final String name;
  final String voiceId;
  final String? samplePath;
  final int createdAt;
  final String provider;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.voiceId,
    this.samplePath,
    required this.createdAt,
    required this.provider,
  });

  factory VoiceProfile.fromMap(Map<String, dynamic> map) {
    return VoiceProfile(
      id: map['id'],
      name: map['name'],
      voiceId: map['voice_id'],
      samplePath: map['sample_path'],
      createdAt: map['created_at'],
      provider: map['provider'] ?? 'cartesia',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'voice_id': voiceId,
      'sample_path': samplePath,
      'created_at': createdAt,
      'provider': provider,
    };
  }

  VoiceProfile copyWith({
    String? name,
    String? voiceId,
    String? samplePath,
    String? provider,
  }) {
    return VoiceProfile(
      id: id,
      name: name ?? this.name,
      voiceId: voiceId ?? this.voiceId,
      samplePath: samplePath ?? this.samplePath,
      createdAt: createdAt,
      provider: provider ?? this.provider,
    );
  }
}
