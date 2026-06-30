import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service.dart';
import '../models/audio_card.dart';
import '../models/storytime_models.dart';
import 'key_value_store.dart';
import 'library_import_service.dart';

class StarterStoryService {
  StarterStoryService({KeyValueStore? store})
    : _store = store ?? SecureKeyValueStore();

  static const manifestAsset = 'assets/storytime/starter_stories.json';

  // Bump when the bundled curated audio changes so already-seeded installs
  // re-import the new files instead of keeping the old recordings. v2 switched
  // the 6 starter stories from placeholder system-TTS .wav to real ElevenLabs
  // narrator .mp3.
  static const _audioVersion = '2';
  static const _audioVersionKey = 'starter_audio_version';

  final KeyValueStore _store;
  static Future<void>? _seeding;

  Future<void> seedIfNeeded() {
    final active = _seeding;
    if (active != null) return active;
    final future = _seed();
    _seeding = future;
    return future.whenComplete(() => _seeding = null);
  }

  Future<void> _seed() async {
    final existing = await DatabaseService.instance.readAllCards();
    final existingById = {for (final card in existing) card.id: card};
    final manifest =
        jsonDecode(await rootBundle.loadString(manifestAsset)) as List<dynamic>;
    final refreshAudio =
        await _store.read(key: _audioVersionKey) != _audioVersion;

    final additions = <AudioCard>[];
    final importedPaths = <String>[];

    try {
      for (var index = 0; index < manifest.length; index++) {
        final item = Map<String, dynamic>.from(manifest[index] as Map);
        final id = item['id'] as String;
        final spriteKey = item['spriteKey'] as String;
        final audioAsset = item['audioAsset'] as String;

        final alreadySeeded = existingById[id];
        if (alreadySeeded != null) {
          await _reconcileExisting(alreadySeeded, spriteKey, audioAsset,
              refreshAudio: refreshAudio);
          continue;
        }

        final managedPath = await _importAsset(audioAsset);
        importedPaths.add(managedPath);

        additions.add(
          AudioCard(
            id: id,
            collectionId: 'default-stories',
            title: item['title'] as String,
            color: item['color'] as String,
            spriteKey: spriteKey,
            audioPath: managedPath,
            storyOrigin: StoryOrigin.curated,
            narratorKey: NarratorKey.values.byName(
              item['narratorKey'] as String,
            ),
            position: existing.length + additions.length,
            createdAt: DateTime.now().millisecondsSinceEpoch + index,
            storyText: item['storyText'] as String?,
          ),
        );
      }

      await DatabaseService.instance.createCards(additions);
      if (refreshAudio) {
        await _store.write(key: _audioVersionKey, value: _audioVersion);
      }
    } catch (_) {
      for (final path in importedPaths) {
        await LibraryImportService.deleteImportedMedia(path);
      }
      rethrow;
    }
  }

  /// Reconciles an already-seeded curated card with the current manifest:
  /// always repoints the sprite key (older builds hashed the title), and when
  /// the audio version bumped, re-imports the new audio and drops the stale
  /// file. A refresh failure propagates and aborts the seed, leaving the
  /// version marker unwritten so it retries next launch; only the stale-file
  /// delete is best-effort, since a leftover old file is harmless.
  Future<void> _reconcileExisting(
    AudioCard card,
    String spriteKey,
    String audioAsset, {
    required bool refreshAudio,
  }) async {
    var updated = card;
    if (card.spriteKey != spriteKey) {
      updated = updated.copyWith(spriteKey: spriteKey);
    }

    String? staleAudio;
    if (refreshAudio) {
      final newPath = await _importAsset(audioAsset);
      staleAudio = card.audioPath;
      updated = updated.copyWith(
        audioPath: newPath,
        playbackPosition: 0,
        durationMs: 0,
      );
    }

    if (!identical(updated, card)) {
      await DatabaseService.instance.updateCard(updated);
    }
    if (staleAudio != null && staleAudio != updated.audioPath) {
      try {
        await LibraryImportService.deleteImportedMedia(staleAudio);
      } catch (_) {
        // A leftover old file is harmless; never fail the seed over cleanup.
      }
    }
  }

  /// Copies a bundled asset to a temp file (preserving its extension so the
  /// player picks the right decoder) and imports it into the managed library.
  Future<String> _importAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dot = assetPath.lastIndexOf('.');
    final ext = dot == -1 ? '' : assetPath.substring(dot);
    final tempDirectory = await getTemporaryDirectory();
    final tempPath = '${tempDirectory.path}/${const Uuid().v4()}$ext';
    await File(tempPath).writeAsBytes(data.buffer.asUint8List());
    return LibraryImportService.importAudioToLibrary(tempPath);
  }
}
