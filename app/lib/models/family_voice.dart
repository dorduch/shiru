import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a family voice clone job.
enum FamilyVoiceStatus {
  consented,
  queued,
  cloning,
  ready,
  failed,
  unknown;

  static FamilyVoiceStatus fromString(String? raw) {
    if (raw == null) return FamilyVoiceStatus.unknown;
    try {
      return FamilyVoiceStatus.values.byName(raw);
    } catch (_) {
      return FamilyVoiceStatus.unknown;
    }
  }

  bool get isProcessing =>
      this == FamilyVoiceStatus.consented ||
      this == FamilyVoiceStatus.queued ||
      this == FamilyVoiceStatus.cloning;
}

/// A single family member voice record as stored in Firestore.
class FamilyVoice {
  const FamilyVoice({
    required this.id,
    required this.name,
    required this.relationship,
    required this.subjectLiving,
    required this.status,
    required this.createdAt,
    this.providerVoiceId,
    this.errorCode,
  });

  final String id;
  final String name;
  final String relationship;
  final bool subjectLiving;
  final FamilyVoiceStatus status;
  final DateTime createdAt;
  final String? providerVoiceId;
  final String? errorCode;

  factory FamilyVoice.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return FamilyVoice(
      id: snapshot.id,
      name: (data['name'] as String?) ?? '',
      relationship: (data['relationship'] as String?) ?? '',
      subjectLiving: (data['subjectLiving'] as bool?) ?? true,
      status: FamilyVoiceStatus.fromString(data['status'] as String?),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      providerVoiceId: data['providerVoiceId'] as String?,
      errorCode: data['errorCode'] as String?,
    );
  }

  /// The narrator key sent to createStoryJob for this voice.
  String get narratorKey => 'family:$id';
}
