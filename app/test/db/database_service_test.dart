import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/db/database_service.dart';
import 'package:shiru/models/category.dart';

void main() {
  test('v6 to v7 migration adds audio-defaulted media type', () async {
    final executedStatements = <String>[];

    await DatabaseService.applyVersion7Migration(
      6,
      (sql) async => executedStatements.add(sql),
    );

    expect(DatabaseService.schemaVersion, 9);
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
    test('fresh databases receive only the Storytime Stories category', () {
      final defaults = DatabaseService.missingDefaultCategories(const []);

      expect(
        defaults
            .map(
              (category) => (category.name, category.emoji, category.position),
            )
            .toList(),
        [('Stories', '📖', 0)],
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

        expect(defaults.map((category) => category.name), ['Stories']);
        expect(defaults.map((category) => category.position), [5]);
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

      expect(firstPass, isEmpty);
      expect(secondPass, isEmpty);
    });

    test('v7 upgrade seeds once and v8 skips seeding', () async {
      var seedCount = 0;

      await DatabaseService.applyVersion8Migration(7, () async => seedCount++);
      await DatabaseService.applyVersion8Migration(8, () async => seedCount++);

      expect(seedCount, 1);
    });

    test('v8 to v9 migration adds Storytime playback metadata once', () async {
      final statements = <String>[];

      await DatabaseService.applyVersion9Migration(
        8,
        (sql) async => statements.add(sql),
      );

      expect(statements, DatabaseService.addStoryMetadataMigration);
      expect(statements.join(' '), contains('is_favorite'));
      expect(statements.join(' '), contains('last_played_at'));

      statements.clear();
      await DatabaseService.applyVersion9Migration(
        9,
        (sql) async => statements.add(sql),
      );
      expect(statements, isEmpty);
    });
  });
}
