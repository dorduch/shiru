import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_card.dart';

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
      version: 1,
      onCreate: _createDB,
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
