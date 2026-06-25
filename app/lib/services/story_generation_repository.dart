import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/storytime_models.dart';

class StoryJob {
  const StoryJob({
    required this.id,
    required this.status,
    required this.theme,
    required this.narratorKey,
    this.title,
    this.downloadUrl,
    this.errorCode,
    this.remaining,
    this.story,
  });

  final String id;
  final StoryJobStatus status;
  final StoryTheme theme;
  final NarratorKey narratorKey;
  final String? title;
  final String? downloadUrl;
  final String? errorCode;
  final int? remaining;
  final String? story;

  factory StoryJob.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return StoryJob(
      id: snapshot.id,
      status: StoryJobStatus.values.byName(data['status'] as String),
      theme: StoryTheme.values.byName(data['theme'] as String),
      narratorKey: NarratorKey.values.byName(data['narratorKey'] as String),
      title: data['title'] as String?,
      downloadUrl: data['downloadUrl'] as String?,
      errorCode: data['errorCode'] as String?,
      remaining: data['remaining'] as int?,
      story: data['story'] as String?,
    );
  }
}

class CreateStoryJobResult {
  const CreateStoryJobResult({required this.jobId, required this.remaining});

  final String jobId;
  final int remaining;
}

abstract class StoryGenerationRepository {
  Future<CreateStoryJobResult> createJob({
    required StoryDraft draft,
    required AgeBand ageBand,
    required String idempotencyKey,
  });
  Stream<StoryJob> watchJob(String uid, String jobId);
  Future<void> confirmImported(String jobId);
  Future<void> joinFamilyVoiceWaitlist();
  Future<void> deleteAccountData();
}

class FirebaseStoryGenerationRepository implements StoryGenerationRepository {
  FirebaseStoryGenerationRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<CreateStoryJobResult> createJob({
    required StoryDraft draft,
    required AgeBand ageBand,
    required String idempotencyKey,
  }) async {
    final response = await _functions.httpsCallable('createStoryJob').call({
      ...draft.toRequestJson(),
      'ageBand': ageBand.name,
      'idempotencyKey': idempotencyKey,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return CreateStoryJobResult(
      jobId: data['jobId'] as String,
      remaining: data['remaining'] as int,
    );
  }

  @override
  Stream<StoryJob> watchJob(String uid, String jobId) => _firestore
      .collection('users')
      .doc(uid)
      .collection('storyJobs')
      .doc(jobId)
      .snapshots()
      .where((snapshot) => snapshot.exists)
      .map(StoryJob.fromSnapshot);

  @override
  Future<void> confirmImported(String jobId) async {
    await _functions.httpsCallable('confirmStoryImported').call({
      'jobId': jobId,
    });
  }

  @override
  Future<void> joinFamilyVoiceWaitlist() async {
    await _functions.httpsCallable('joinFamilyVoiceWaitlist').call();
  }

  @override
  Future<void> deleteAccountData() async {
    await _functions.httpsCallable('deleteAccountData').call();
  }
}
