import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/logic/story_tokenizer.dart';

/// The read-along highlight only stays aligned if the rendered word spans, the
/// timing array, and the index lookup all agree on the word count. The renderer
/// and the index both derive from [tokenizeStory]; this asserts the bundled
/// timing files (built by functions/dev/generate_starter_stories.mjs) agree —
/// so a regenerate that changes tokenization can't silently drift the gold word.
void main() {
  test('each curated timing file has one entry per tokenized word', () {
    const dir = 'assets/storytime';
    final manifest = (jsonDecode(
      File('$dir/starter_stories.json').readAsStringSync(),
    ) as List)
        .cast<Map<String, dynamic>>();

    expect(manifest, isNotEmpty);

    for (final story in manifest) {
      final id = story['id'] as String;
      final timingAsset = story['timingAsset'] as String?;
      expect(timingAsset, isNotNull, reason: '$id missing timingAsset');

      final wordCount = tokenizeStory(story['storyText'] as String).length;
      final timing =
          jsonDecode(File(timingAsset!).readAsStringSync()) as Map;
      final timingWords = (timing['words'] as List).length;

      expect(
        timingWords,
        wordCount,
        reason: '$id: timing has $timingWords words but tokenizer found '
            '$wordCount — highlight would drift',
      );
    }
  });
}
