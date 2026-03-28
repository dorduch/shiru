import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_card.dart';
import '../models/category.dart';
import '../models/voice_profile.dart';

/// Key under which the DB encryption password is stored in secure storage.
const _kDbPasswordKey = 'db_encryption_key';

class DatabaseService {
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
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: _kDbPasswordKey);
    if (key == null) {
      final rng = Random.secure();
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      key = List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
      await storage.write(key: _kDbPasswordKey, value: key);
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
        version: 6,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }

    // --- Existing DB: try opening with encryption password -------------------
    try {
      return await openDatabase(
        path,
        version: 6,
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
      await dbFile.delete();
      return await openDatabase(
        path,
        version: 6,
        password: password,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }

    await dbFile.delete();

    final newDb = await openDatabase(
      path,
      version: 6,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    await newDb.transaction((txn) async {
      for (final row in legacyCards) {
        await txn.insert('cards', row);
      }
      for (final row in legacyCategories) {
        await txn.insert('categories', row);
      }
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
  playback_position INTEGER DEFAULT 0,
  position INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL
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

    await db.execute('''
CREATE TABLE voice_profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sample_path TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
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
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE voice_profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  elevenlabs_voice_id TEXT NOT NULL,
  sample_path TEXT,
  created_at INTEGER NOT NULL
)
''');
    }
    if (oldVersion < 4) {
      await db.transaction((txn) async {
        await txn.execute('''
CREATE TABLE voice_profiles_new (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  voice_id TEXT NOT NULL,
  sample_path TEXT,
  created_at INTEGER NOT NULL
)
''');
        await txn.execute('''
INSERT INTO voice_profiles_new
SELECT id, name, elevenlabs_voice_id, sample_path, created_at
FROM voice_profiles
''');
        await txn.execute('DROP TABLE voice_profiles');
        await txn.execute('ALTER TABLE voice_profiles_new RENAME TO voice_profiles');
      });
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE voice_profiles ADD COLUMN provider TEXT NOT NULL DEFAULT 'cartesia'");
    }
    if (oldVersion < 6) {
      await db.transaction((txn) async {
        await txn.execute('''
CREATE TABLE voice_profiles_new (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sample_path TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
        await txn.execute('''
INSERT INTO voice_profiles_new
SELECT id, name, sample_path, created_at
FROM voice_profiles
WHERE sample_path IS NOT NULL
''');
        await txn.execute('DROP TABLE voice_profiles');
        await txn.execute('ALTER TABLE voice_profiles_new RENAME TO voice_profiles');
      });
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
    final result = await db.query('cards', orderBy: 'position ASC, created_at DESC');
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
    return await db.delete(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // ---------------------------------------------------------------------------
  // CRUD — voice profiles
  // ---------------------------------------------------------------------------

  Future<VoiceProfile> createVoiceProfile(VoiceProfile profile) async {
    final db = await instance.database;
    await db.insert('voice_profiles', profile.toMap());
    return profile;
  }

  Future<List<VoiceProfile>> readAllVoiceProfiles() async {
    final db = await instance.database;
    final result = await db.query('voice_profiles', orderBy: 'created_at DESC');
    return result.map((map) => VoiceProfile.fromMap(map)).toList();
  }

  Future<int> deleteVoiceProfile(String id) async {
    final db = await instance.database;
    return await db.delete(
      'voice_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
