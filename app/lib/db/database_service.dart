import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_card.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('yoto.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

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
  }

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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
