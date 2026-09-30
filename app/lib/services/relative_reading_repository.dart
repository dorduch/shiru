import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/relative_reading.dart';
import '../models/storytime_models.dart';
import 'library_import_service.dart';

/// Parent-side relative reading queue: list pending, preview URL, approve→library, reject.
class RelativeReadingRepository {
  RelativeReadingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _http = httpClient ?? http.Client();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final http.Client _http;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('relativeReadings');

  /// Live pending queue for the signed-in parent.
  Stream<List<RelativeReading>> watchPending(String uid) {
    return _col(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((doc) => RelativeReading.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) {
        final am = a.createdAtMillis ?? 0;
        final bm = b.createdAtMillis ?? 0;
        return bm.compareTo(am);
      });
      return items;
    });
  }

  Future<({String downloadUrl, String mimeType})> getPreviewUrl(
    String readingId,
  ) async {
    final response = await _functions
        .httpsCallable('getRelativeReadingAudioUrl')
        .call({'readingId': readingId});
    final data = Map<String, dynamic>.from(response.data as Map);
    return (
      downloadUrl: data['downloadUrl'] as String,
      mimeType: (data['mimeType'] as String?) ?? 'audio/mp4',
    );
  }

  Future<void> reject(String readingId) async {
    await _functions.httpsCallable('decideRelativeReading').call({
      'readingId': readingId,
      'decision': 'reject',
    });
  }

  /// Approves (idempotent) and imports into the local library when needed.
  ///
  /// Uses [readingId] as the [AudioCard.id] so a second approve is a no-op
  /// once the card exists. Rejected audio never reaches this path.
  Future<AudioCard?> approveAndImport({
    required String readingId,
    required RelativeReading reading,
    required List<AudioCard> existingCards,
    required Future<void> Function(AudioCard card) addCard,
  }) async {
    final existing = existingCards.where((c) => c.id == readingId).firstOrNull;
    if (existing != null) return existing;

    final response = await _functions.httpsCallable('decideRelativeReading').call({
      'readingId': readingId,
      'decision': 'approve',
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final downloadUrl = data['downloadUrl'] as String?;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw StateError('Approved reading had no download URL.');
    }
    final mimeType = (data['mimeType'] as String?) ?? reading.mimeType ?? 'audio/mp4';

    final ext = _extensionForMime(mimeType);
    final httpResponse = await _http.get(Uri.parse(downloadUrl));
    if (httpResponse.statusCode != 200 || httpResponse.bodyBytes.isEmpty) {
      throw HttpException('Could not download reading audio.');
    }

    final temp = await getTemporaryDirectory();
    final tempPath = p.join(temp.path, '${const Uuid().v4()}.$ext');
    await File(tempPath).writeAsBytes(httpResponse.bodyBytes);

    final importedPath = await LibraryImportService.importAudioToLibrary(tempPath);
    try {
      await File(tempPath).delete();
    } catch (_) {}

    final durationMs = reading.durationSeconds == null
        ? 0
        : (reading.durationSeconds! * 1000).round();

    final card = AudioCard(
      id: readingId,
      collectionId: 'default-stories',
      title: reading.displayName,
      color: '#FF9B8A',
      audioPath: importedPath,
      mediaType: CardMediaType.audio,
      storyOrigin: StoryOrigin.relative,
      durationMs: durationMs,
      position: existingCards.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await addCard(card);
    } catch (_) {
      // Idempotent double-approve: card id == readingId already present.
      final raced = existingCards.where((c) => c.id == readingId).firstOrNull;
      if (raced != null) return raced;
      return card;
    }
    return card;
  }

  static String _extensionForMime(String mimeType) {
    final base = mimeType.split(';').first.trim();
    if (base == 'audio/webm') return 'webm';
    if (base == 'audio/mp4' || base == 'audio/aac') return 'm4a';
    return 'm4a';
  }
}
