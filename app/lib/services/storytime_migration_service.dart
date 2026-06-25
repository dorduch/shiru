import 'dart:convert';
import 'dart:io';

import '../db/database_service.dart';
import 'key_value_store.dart';
import 'library_import_service.dart';

class StorytimeMigrationService {
  StorytimeMigrationService({KeyValueStore? store})
    : _store = store ?? SecureKeyValueStore();

  static const _migrationKey = 'storytime_destructive_migration_v1';
  static const _cleanupKey = 'storytime_cleanup_tombstones_v1';

  final KeyValueStore _store;

  Future<void> runIfNeeded() async {
    if (await _store.read(key: _migrationKey) == 'complete') {
      await _retryCleanup();
      return;
    }

    final cards = await DatabaseService.instance.readAllCards();
    final paths = <String>{
      for (final card in cards) card.mediaPath,
      for (final card in cards)
        if (card.customImagePath != null) card.customImagePath!,
    };

    await DatabaseService.instance.resetForStorytime();
    final failed = await _deletePaths(paths);
    await _store.write(key: _cleanupKey, value: jsonEncode(failed));
    await _store.write(key: _migrationKey, value: 'complete');
  }

  Future<void> _retryCleanup() async {
    final encoded = await _store.read(key: _cleanupKey);
    if (encoded == null || encoded.isEmpty) return;
    final paths = (jsonDecode(encoded) as List<dynamic>).cast<String>().toSet();
    if (paths.isEmpty) return;
    final failed = await _deletePaths(paths);
    await _store.write(key: _cleanupKey, value: jsonEncode(failed));
  }

  Future<List<String>> _deletePaths(Set<String> paths) async {
    final failed = <String>[];
    for (final path in paths) {
      try {
        await LibraryImportService.deleteImportedMedia(path);
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        failed.add(path);
      }
    }
    return failed;
  }
}
