import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/db/database_service.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/category.dart';

void main() {
  test('v6 to v7 migration adds audio-defaulted media type', () async {
    final executedStatements = <String>[];

    await DatabaseService.applyVersion7Migration(
      6,
      (sql) async => executedStatements.add(sql),
    );

    expect(DatabaseService.schemaVersion, 8);
    expect(executedStatements, [DatabaseService.addMediaTypeMigration]);
    expect(executedStatements.single, contains("DEFAULT 'audio'"));
  });

  test('v7 databases do not repeat the media type migration', () async {
    final executedStatements = <String>[];

    await DatabaseService.applyVersion7Migration(
      7,
      (sql) async => executedStatements.add(sql),
    );

    expect(executedStatements, isEmpty);
  });

  group('default category migration', () {
    test('fresh databases receive Stories and Songs in order', () {
      final defaults = DatabaseService.missingDefaultCategories(const []);

      expect(
        defaults
            .map(
              (category) => (category.name, category.emoji, category.position),
            )
            .toList(),
        [('Stories', '📖', 0), ('Songs', '🎵', 1)],
      );
    });

    test(
      'upgrade preserves existing categories and appends missing defaults',
      () {
        final existing = Category(
          id: 'user-category',
          name: 'Podcasts',
          emoji: '🎧',
          position: 4,
        );

        final defaults = DatabaseService.missingDefaultCategories([existing]);

        expect(defaults.map((category) => category.name), ['Stories', 'Songs']);
        expect(defaults.map((category) => category.position), [5, 6]);
      },
    );

    test('upgrade reuses matching user categories and is idempotent', () {
      final existing = [
        Category(
          id: 'user-stories',
          name: ' stories ',
          emoji: '📚',
          position: 0,
        ),
      ];

      final firstPass = DatabaseService.missingDefaultCategories(existing);
      final secondPass = DatabaseService.missingDefaultCategories([
        ...existing,
        ...firstPass,
      ]);

      expect(firstPass.map((category) => category.name), ['Songs']);
      expect(secondPass, isEmpty);
    });

    test('v7 upgrade seeds once and v8 skips seeding', () async {
      var seedCount = 0;

      await DatabaseService.applyVersion8Migration(7, () async => seedCount++);
      await DatabaseService.applyVersion8Migration(8, () async => seedCount++);

      expect(seedCount, 1);
    });
  });

  group('word_starts column', () {
    test('v10 to v11 migration adds the word_starts column', () async {
      final executedStatements = <String>[];

      await DatabaseService.applyVersion11Migration(
        10,
        (sql) async => executedStatements.add(sql),
      );

      expect(executedStatements, [
        'ALTER TABLE cards ADD COLUMN word_starts TEXT',
      ]);
    });

    test('v11 databases do not repeat the word_starts migration', () async {
      final executedStatements = <String>[];

      await DatabaseService.applyVersion11Migration(
        11,
        (sql) async => executedStatements.add(sql),
      );

      expect(executedStatements, isEmpty);
    });

    test(
      'AudioCard with non-null wordStarts round-trips through toMap/fromMap',
      () {
        final card = AudioCard(
          id: 'card-1',
          title: 'Story',
          color: '#FFFFFF',
          audioPath: '/library/story.mp3',
          position: 0,
          createdAt: 123,
          wordStarts: const [0.0, 0.42, 1.1],
        );

        final map = card.toMap();
        expect(map['word_starts'], '[0.0,0.42,1.1]');

        final restored = AudioCard.fromMap(map);
        expect(restored.wordStarts, const [0.0, 0.42, 1.1]);
      },
    );
  });
}
