import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/family_voice.dart';

/// Repository for family voice cloning — mirrors
/// [FirebaseStoryGenerationRepository] in story_generation_repository.dart.
class VoiceRepository {
  VoiceRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // ─── Firestore stream ────────────────────────────────────────────────────

  /// Streams all voices for [uid], ordered by creation time.
  Stream<List<FamilyVoice>> watchVoices(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('voices')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(FamilyVoice.fromSnapshot).toList(),
      );

  // ─── Callables ───────────────────────────────────────────────────────────

  /// Step 1 — create consent record; returns the new voiceId.
  Future<String> createConsent({
    required String name,
    required String relationship,
  }) async {
    final response = await _functions
        .httpsCallable('createVoiceConsent')
        .call({'name': name, 'relationship': relationship});
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['voiceId'] as String;
  }

  /// Step 2 — upload each sample file to Storage, then call submitVoiceClone.
  ///
  /// Sample paths are uploaded to `voice-samples/{uid}/{voiceId}/{idx}.m4a`.
  /// Files that are not .m4a are still uploaded under the .m4a path because
  /// the backend contract specifies that extension.
  Future<void> uploadSamplesAndClone({
    required String uid,
    required String voiceId,
    required List<String> localFilePaths,
  }) async {
    final storagePaths = <String>[];

    for (var i = 0; i < localFilePaths.length; i++) {
      final storagePath = 'voice-samples/$uid/$voiceId/$i.m4a';
      final ref = _storage.ref(storagePath);
      await ref.putFile(
        File(localFilePaths[i]),
        SettableMetadata(contentType: 'audio/m4a'),
      );
      storagePaths.add(storagePath);
    }

    await _functions
        .httpsCallable('submitVoiceClone')
        .call({'voiceId': voiceId, 'samplePaths': storagePaths});
  }

  /// Delete a voice record (and backend resources).
  Future<void> deleteVoice(String voiceId) async {
    await _functions
        .httpsCallable('deleteVoice')
        .call({'voiceId': voiceId});
  }

  /// Creates a shareable invite link so someone else can record this voice's
  /// samples from any browser. Returns the invite `url` and its `expiresAt`
  /// (ISO 8601 string), mirroring the pinned `createVoiceInvite` contract.
  Future<({String url, String expiresAt})> createInvite(String voiceId) async {
    final response = await _functions
        .httpsCallable('createVoiceInvite')
        .call({'voiceId': voiceId});
    final data = Map<String, dynamic>.from(response.data as Map);
    return (url: data['url'] as String, expiresAt: data['expiresAt'] as String);
  }
}
