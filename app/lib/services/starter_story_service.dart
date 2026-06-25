import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service.dart';
import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../models/storytime_models.dart';
import 'library_import_service.dart';

class StarterStoryService {
  static const manifestAsset = 'assets/storytime/starter_stories.json';
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
    final existingIds = existing.map((card) => card.id).toSet();
    final manifest =
        jsonDecode(await rootBundle.loadString(manifestAsset)) as List<dynamic>;
    final additions = <AudioCard>[];
    final importedPaths = <String>[];

    try {
      for (var index = 0; index < manifest.length; index++) {
        final item = Map<String, dynamic>.from(manifest[index] as Map);
        final id = item['id'] as String;
        if (existingIds.contains(id)) continue;

        final data = await rootBundle.load(item['audioAsset'] as String);
        final tempDirectory = await getTemporaryDirectory();
        final tempPath = '${tempDirectory.path}/${const Uuid().v4()}.wav';
        await File(tempPath).writeAsBytes(data.buffer.asUint8List());
        final managedPath = await LibraryImportService.importAudioToLibrary(
          tempPath,
        );
        importedPaths.add(managedPath);
        final title = item['title'] as String;

        additions.add(
          AudioCard(
            id: id,
            collectionId: 'default-stories',
            title: title,
            color: item['color'] as String,
            spriteKey: autoAssignSprite(title).id,
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
    } catch (_) {
      for (final path in importedPaths) {
        await LibraryImportService.deleteImportedMedia(path);
      }
      rethrow;
    }
  }
}
