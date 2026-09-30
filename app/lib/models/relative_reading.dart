/// Parent-facing relative reading waiting for approve / reject.
///
/// Mirrors `users/{uid}/relativeReadings/{id}` fields used by the MVP pipe.
/// Caps (duration / bytes) are display-only when present — not product framing.
class RelativeReading {
  const RelativeReading({
    required this.id,
    required this.status,
    required this.name,
    required this.relationship,
    required this.storagePath,
    this.mimeType,
    this.durationSeconds,
    this.byteSize,
    this.voiceId,
    this.createdAtMillis,
  });

  final String id;
  final String status; // pending | approved | rejected
  final String name;
  final String relationship;
  final String storagePath;
  final String? mimeType;
  final double? durationSeconds;
  final int? byteSize;
  final String? voiceId;
  final int? createdAtMillis;

  bool get isPending => status == 'pending';

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final rel = relationship.trim();
    if (rel.isNotEmpty) return rel;
    return 'Family';
  }

  String get subtitle {
    final rel = relationship.trim();
    if (rel.isNotEmpty && rel.toLowerCase() != displayName.toLowerCase()) {
      return rel;
    }
    return 'Waiting for your review';
  }

  factory RelativeReading.fromMap(String id, Map<String, dynamic> data) {
    final statusRaw = data['status'];
    final status = statusRaw == 'approved' || statusRaw == 'rejected'
        ? statusRaw as String
        : 'pending';
    final duration = data['durationSeconds'];
    final createdAt = data['createdAt'];
    int? createdAtMillis;
    if (createdAt is int) {
      createdAtMillis = createdAt;
    } else {
      // Firestore Timestamp duck-type without importing cloud_firestore here.
      try {
        createdAtMillis =
            (createdAt as dynamic).millisecondsSinceEpoch as int?;
      } catch (_) {
        createdAtMillis = null;
      }
    }
    return RelativeReading(
      id: id,
      status: status,
      name: data['name'] is String ? data['name'] as String : '',
      relationship:
          data['relationship'] is String ? data['relationship'] as String : '',
      storagePath:
          data['storagePath'] is String ? data['storagePath'] as String : '',
      mimeType: data['mimeType'] is String ? data['mimeType'] as String : null,
      durationSeconds: duration is num ? duration.toDouble() : null,
      byteSize: data['byteSize'] is int
          ? data['byteSize'] as int
          : data['byteSize'] is num
              ? (data['byteSize'] as num).toInt()
              : null,
      voiceId: data['voiceId'] is String ? data['voiceId'] as String : null,
      createdAtMillis: createdAtMillis,
    );
  }
}
