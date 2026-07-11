import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_card.dart';
import '../models/category.dart';
import '../services/key_value_store.dart';

/// Key under which the DB encryption password is stored in secure storage.
const _kDbPasswordKey = 'db_encryption_key';

class DatabaseService {
  static const int schemaVersion = 11;
  static const String addMediaTypeMigration =
      "ALTER TABLE cards ADD COLUMN media_type TEXT NOT NULL DEFAULT 'audio'";
  static const List<String> addStoryMetadataMigration = [
    "ALTER TABLE cards ADD COLUMN story_origin TEXT NOT NULL DEFAULT 'generated'",
    'ALTER TABLE cards ADD COLUMN narrator_key TEXT',
    'ALTER TABLE cards ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE cards ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE cards ADD COLUMN last_played_at INTEGER',
  ];
  static final List<Category> defaultCategories = List.unmodifiable([
    Category(id: 'default-stories', name: 'Stories', emoji: '📖', position: 0),
  ]);
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('yoto.db');
    return _database!;
  }

  // ---------------------------------------------------------------------------
  // Key management
  // ---------------------------------------------------------------------------

  /// Returns the encryption key, generating and persisting it on first launch.
  Future<String> _getOrCreateEncryptionKey() async {
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    String? key = await storage.read(key: _kDbPasswordKey);
    if (key == null) {
      final rng = Random.secure();
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      key = List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
      try {
        await storage.write(key: _kDbPasswordKey, value: key);
      } on PlatformException catch (error) {
        if (!isDuplicateKeychainItemError(error)) rethrow;

        await storage.delete(key: _kDbPasswordKey);
        await storage.write(key: _kDbPasswordKey, value: key);
      }
    }
    return key;
  }

  // ---------------------------------------------------------------------------
  // DB initialisation with migration for legacy unencrypted databases
  // ---------------------------------------------------------------------------

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final password = await _getOrCreateEncryptionKey();

    final dbFile = File(path);
    final fileExists = await dbFile.exists();

    // --- Fresh install: no existing DB, create a new encrypted one -----------
    if (!fileExists) {
      return await openDatabase(
        path,
        version: schemaVersion,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }

    // --- Existing DB: try opening with encryption password -------------------
    try {
      return await openDatabase(
        path,
        version: schemaVersion,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (_) {
      // Opening with a password failed — likely a legacy unencrypted DB.
    }

    // --- Legacy migration: export data, re-create as encrypted ---------------
    late final List<Map<String, dynamic>> legacyCards;
    late final List<Map<String, dynamic>> legacyCategories;

    try {
      final legacyDb = await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );

      legacyCards = await legacyDb.query('cards');
      legacyCategories = await legacyDb.query('categories');
      await legacyDb.close();
    } catch (e) {
      // DB exists but can't be opened as encrypted or unencrypted.
      // This happens in development when the APK is reinstalled (wiping
      // flutter_secure_storage) while the DB file survives. Recover by
      // deleting the inaccessible file and starting fresh.
      if (kDebugMode) {
        debugPrint(
          '[DatabaseService] WARNING: DB at $path could not be opened. '
          'Deleting and starting fresh. Error: $e',
        );
      }
      await dbFile.delete();
      return await openDatabase(
        path,
        version: schemaVersion,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }

    await dbFile.delete();

    final newDb = await openDatabase(
      path,
      version: schemaVersion,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    await newDb.transaction((txn) async {
      // _createDB seeded defaults. Restore the legacy categories first so an
      // existing category named Stories or Songs remains the user's category.
      await txn.delete('categories');
      for (final row in legacyCards) {
        await txn.insert('cards', row);
      }
      for (final row in legacyCategories) {
        await txn.insert('categories', row);
      }
      await _ensureDefaultCategories(txn);
    });

    return newDb;
  }

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  collection_id TEXT,
  title TEXT NOT NULL,
  color TEXT NOT NULL,
  sprite_key TEXT,
  custom_image_path TEXT,
  audio_path TEXT NOT NULL,
  media_type TEXT NOT NULL DEFAULT 'audio',
  playback_position INTEGER DEFAULT 0,
  story_origin TEXT NOT NULL DEFAULT 'generated',
  narrator_key TEXT,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  last_played_at INTEGER,
  position INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  story_text TEXT,
  word_starts TEXT
)
''');

    await db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  position INTEGER DEFAULT 0
)
''');

    await _ensureDefaultCategories(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  position INTEGER DEFAULT 0
)
''');
    }
    await applyVersion7Migration(oldVersion, db.execute);
    await applyVersion8Migration(
      oldVersion,
      () => _ensureDefaultCategories(db),
    );
    await applyVersion9Migration(oldVersion, db.execute);
    await applyVersion10Migration(oldVersion, db.execute);
    await applyVersion11Migration(oldVersion, db.execute);
  }

  @visibleForTesting
  static Future<void> applyVersion7Migration(
    int oldVersion,
    Future<void> Function(String sql) execute,
  ) async {
    if (oldVersion < 7) await execute(addMediaTypeMigration);
  }

  @visibleForTesting
  static Future<void> applyVersion8Migration(
    int oldVersion,
    Future<void> Function() seedDefaults,
  ) async {
    if (oldVersion < 8) await seedDefaults();
  }

  @visibleForTesting
  static Future<void> applyVersion9Migration(
    int oldVersion,
    Future<void> Function(String sql) execute,
  ) async {
    if (oldVersion >= 9) return;
    for (final statement in addStoryMetadataMigration) {
      await execute(statement);
    }
  }

  @visibleForTesting
  static Future<void> applyVersion10Migration(
    int oldVersion,
    Future<void> Function(String sql) execute,
  ) async {
    if (oldVersion < 10) await execute('ALTER TABLE cards ADD COLUMN story_text TEXT');
  }

  @visibleForTesting
  static Future<void> applyVersion11Migration(
    int oldVersion,
    Future<void> Function(String sql) execute,
  ) async {
    if (oldVersion < 11) {
      await execute('ALTER TABLE cards ADD COLUMN word_starts TEXT');
    }
  }

  @visibleForTesting
  static List<Category> missingDefaultCategories(
    Iterable<Category> existingCategories,
  ) {
    final existing = existingCategories.toList();
    final existingIds = existing.map((category) => category.id).toSet();
    final existingNames = existing
        .map((category) => category.name.trim().toLowerCase())
        .toSet();
    var nextPosition = existing.fold<int>(
      0,
      (next, category) => max(next, category.position + 1),
    );

    final missing = <Category>[];
    for (final category in defaultCategories) {
      final normalizedName = category.name.toLowerCase();
      if (existingIds.contains(category.id) ||
          existingNames.contains(normalizedName)) {
        continue;
      }

      missing.add(category.copyWith(position: nextPosition++));
    }
    return missing;
  }

  static Future<void> _ensureDefaultCategories(DatabaseExecutor db) async {
    final rows = await db.query('categories');
    final existing = rows.map(Category.fromMap);
    for (final category in missingDefaultCategories(existing)) {
      await db.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD — cards
  // ---------------------------------------------------------------------------

  Future<AudioCard> createCard(AudioCard card) async {
    final db = await instance.database;
    await db.insert('cards', card.toMap());
    return card;
  }

  Future<void> createCards(List<AudioCard> cards) async {
    if (cards.isEmpty) return;

    final db = await instance.database;
    await db.transaction((txn) async {
      for (final card in cards) {
        await txn.insert('cards', card.toMap());
      }
    });
  }

  Future<void> replaceCards(List<AudioCard> cards) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('cards');
      for (final card in cards) {
        await txn.insert('cards', card.toMap());
      }
    });
  }

  Future<void> resetForStorytime() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('cards');
      await txn.delete('categories');
      await _ensureDefaultCategories(txn);
    });
  }

  Future<AudioCard> readCard(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'cards',
      columns: null,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return AudioCard.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<AudioCard>> readAllCards() async {
    final db = await instance.database;
    final result = await db.query(
      'cards',
      orderBy: 'position ASC, created_at DESC',
    );
    return result.map((map) => AudioCard.fromMap(map)).toList();
  }

  Future<int> updateCard(AudioCard card) async {
    final db = await instance.database;
    return db.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(String id) async {
    final db = await instance.database;
    return await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countCardsWithAudioPath(String audioPath) async {
    return countCardsWithMediaPath(audioPath);
  }

  Future<int> countCardsWithMediaPath(String mediaPath) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM cards WHERE audio_path = ?',
      [mediaPath],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // CRUD — categories
  // ---------------------------------------------------------------------------

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'position ASC');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category> createCategory(Category category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategoryAndUnassignCards(String id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'cards',
        {'collection_id': null},
        where: 'collection_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> batchUpdateCategoryPositions(List<Category> categories) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final cat in categories) {
        await txn.update(
          'categories',
          {'position': cat.position},
          where: 'id = ?',
          whereArgs: [cat.id],
        );
      }
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
