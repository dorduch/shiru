import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/story_options.dart';

void main() {
  group('StoryHero', () {
    test('every hero has a non-empty displayName, emoji, and promptName', () {
      for (final hero in StoryHero.values) {
        expect(hero.displayName, isNotEmpty, reason: '${hero.name}.displayName');
        expect(hero.emoji, isNotEmpty, reason: '${hero.name}.emoji');
        expect(hero.promptName, isNotEmpty, reason: '${hero.name}.promptName');
      }
    });

    test('has exactly 10 heroes', () {
      expect(StoryHero.values.length, 10);
    });
  });

  group('StoryTheme', () {
    test('every theme has a non-empty displayName, emoji, promptName, and color', () {
      for (final theme in StoryTheme.values) {
        expect(theme.displayName, isNotEmpty, reason: '${theme.name}.displayName');
        expect(theme.emoji, isNotEmpty, reason: '${theme.name}.emoji');
        expect(theme.promptName, isNotEmpty, reason: '${theme.name}.promptName');
        expect(
          theme.color,
          matches(RegExp(r'^#[0-9a-fA-F]{6}$')),
          reason: '${theme.name}.color should be a 6-digit hex color',
        );
      }
    });

    test('has exactly 10 themes', () {
      expect(StoryTheme.values.length, 10);
    });
  });

  group('StoryLanguage', () {
    test('every language has a non-empty displayName, flag, and promptLabel', () {
      for (final lang in StoryLanguage.values) {
        expect(lang.displayName, isNotEmpty);
        expect(lang.flag, isNotEmpty);
        expect(lang.promptLabel, isNotEmpty);
      }
    });

    test('has exactly 3 languages: en, he, es', () {
      expect(StoryLanguage.values.length, 3);
      expect(StoryLanguage.values.map((l) => l.name).toList(),
          containsAll(['en', 'he', 'es']));
    });
  });

  group('StoryLength', () {
    test('short has fewer target words than long', () {
      expect(StoryLength.short.targetWordCount,
          lessThan(StoryLength.long.targetWordCount));
    });

    test('both lengths have non-empty displayNames', () {
      expect(StoryLength.short.displayName, isNotEmpty);
      expect(StoryLength.long.displayName, isNotEmpty);
    });
  });
}
