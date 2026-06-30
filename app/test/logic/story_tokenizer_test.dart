import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/logic/story_tokenizer.dart';

void main() {
  group('tokenizeStory', () {
    test('splits on whitespace and records char ranges', () {
      final words = tokenizeStory('The brave fox');
      expect(words.map((w) => w.start), [0, 4, 10]);
      expect(words.map((w) => w.end), [3, 9, 13]);
    });

    test('counts words across paragraph breaks the same as a plain split', () {
      const text = 'down.\n\nPip jumped.  Then\nhe ran.';
      // 6 words: down. Pip jumped. Then he ran.
      expect(tokenizeStory(text).length, 6);
    });

    test('ignores leading/trailing whitespace', () {
      expect(tokenizeStory('  hi there \n').length, 2);
      expect(tokenizeStory('   ').length, 0);
      expect(tokenizeStory('').length, 0);
    });
  });

  group('wordIndexForTime', () {
    final starts = [0.0, 0.5, 1.0, 2.0, 5.0];

    test('returns null before the first word', () {
      expect(wordIndexForTime(starts, -0.1), isNull);
      expect(wordIndexForTime([], 3.0), isNull);
    });

    test('returns the last word started at or before the position', () {
      expect(wordIndexForTime(starts, 0.0), 0);
      expect(wordIndexForTime(starts, 0.49), 0);
      expect(wordIndexForTime(starts, 0.5), 1);
      expect(wordIndexForTime(starts, 1.999), 2);
      expect(wordIndexForTime(starts, 2.0), 3);
      expect(wordIndexForTime(starts, 100.0), 4);
    });
  });
}
