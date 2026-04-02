import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/sprites.dart';

void main() {
  group('SpriteCategory', () {
    test('has three values', () {
      expect(SpriteCategory.values.length, 3);
      expect(SpriteCategory.values, containsAll([
        SpriteCategory.animals,
        SpriteCategory.fantasy,
        SpriteCategory.sciFi,
      ]));
    });
  });

  group('SpriteDef', () {
    test('defaults to sciFi category', () {
      final sprite = SpriteDef(
        id: 'test',
        name: 'Test',
        palette: ['#00000000', '#FF0000FF'],
        frames: {
          'idle': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
          'active': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
          'tap': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
        },
        fps: const {'idle': 4, 'active': 8, 'tap': 15},
      );
      expect(sprite.category, SpriteCategory.sciFi);
    });

    test('all predefined sprites have a category', () {
      for (final sprite in predefinedSprites.values) {
        expect(sprite.category, isNotNull,
            reason: 'Sprite ${sprite.id} is missing a category');
      }
    });

    test('all predefined sprites are tagged sciFi by default', () {
      for (final sprite in predefinedSprites.values) {
        expect(sprite.category, SpriteCategory.sciFi,
            reason: 'Sprite ${sprite.id} should be sciFi');
      }
    });
  });

  group('predefinedSprites', () {
    test('contains at least 103 entries', () {
      expect(predefinedSprites.length, greaterThanOrEqualTo(103));
    });

    test('lookup by key returns correct sprite', () {
      expect(predefinedSprites['moon']?.name, 'Moon');
      expect(predefinedSprites['rocket']?.name, 'Rocket');
      expect(predefinedSprites['dog']?.name, 'Dog');
    });

    test('autoAssignSprite returns a SpriteDef', () {
      final sprite = autoAssignSprite('Test Card Title');
      expect(sprite, isA<SpriteDef>());
      expect(sprite.id, isNotEmpty);
    });
  });
}
