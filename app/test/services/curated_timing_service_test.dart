import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/services/curated_timing_service.dart';
import 'package:shiru/services/starter_story_service.dart';

/// Minimal in-memory [AssetBundle] so [CuratedTimingService]'s runtime guard
/// can be exercised without touching the real bundled assets.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._strings);
  final Map<String, String> _strings;

  @override
  Future<ByteData> load(String key) async {
    final value = _strings[key];
    if (value == null) throw Exception('Asset not found: $key');
    return ByteData.view(Uint8List.fromList(utf8.encode(value)).buffer);
  }
}

Map<String, String> _manifestWith({
  required String id,
  required String storyText,
  required String timingAsset,
}) {
  return {
    StarterStoryService.manifestAsset: jsonEncode([
      {
        'id': id,
        'spriteKey': 'fox',
        'audioAsset': 'assets/storytime/$id.mp3',
        'title': 'Test story',
        'color': '#FFFFFF',
        'narratorKey': 'warm',
        'storyText': storyText,
        'timingAsset': timingAsset,
      },
    ]),
  };
}

String _timingJson(List<double> starts) {
  return jsonEncode({
    'words': [for (final s in starts) {'start': s}],
  });
}

void main() {
  // The regression this guards against: a bundled `.timing.json` whose word
  // count (or shape) has drifted from the manifest's `storyText` — a stale
  // regeneration, a hand-edited story, or a bad build — would otherwise
  // silently desync the read-along highlight from the words on screen.
  // Mirrors the backend's `deriveWordStarts` sanity gate
  // (functions/src/timing.ts).
  group('CuratedTimingService', () {
    test('returns word starts when the timing word count matches storyText',
        () async {
      const id = 'story-a';
      const timingAsset = 'assets/storytime/story-a.timing.json';
      final strings = _manifestWith(
        id: id,
        storyText: 'Once upon a time',
        timingAsset: timingAsset,
      );
      strings[timingAsset] = _timingJson([0.0, 0.5, 1.0, 1.5]);

      final service = CuratedTimingService(bundle: _FakeAssetBundle(strings));
      final result = await service.wordStartsFor(id);

      expect(result, [0.0, 0.5, 1.0, 1.5]);
    });

    test(
        'falls back to null when the timing word count does not match '
        'storyText', () async {
      const id = 'story-b';
      const timingAsset = 'assets/storytime/story-b.timing.json';
      final strings = _manifestWith(
        id: id,
        storyText: 'Once upon a time', // 4 words
        timingAsset: timingAsset,
      );
      strings[timingAsset] = _timingJson([0.0, 0.5, 1.0]); // only 3 starts

      final service = CuratedTimingService(bundle: _FakeAssetBundle(strings));
      final result = await service.wordStartsFor(id);

      expect(result, isNull);
    });

    test('falls back to null when timing starts are not non-decreasing',
        () async {
      const id = 'story-c';
      const timingAsset = 'assets/storytime/story-c.timing.json';
      final strings = _manifestWith(
        id: id,
        storyText: 'Once upon a',
        timingAsset: timingAsset,
      );
      strings[timingAsset] = _timingJson([0.0, 2.0, 1.0]); // goes backwards

      final service = CuratedTimingService(bundle: _FakeAssetBundle(strings));
      final result = await service.wordStartsFor(id);

      expect(result, isNull);
    });

    test('returns null for a card with no manifest entry', () async {
      const timingAsset = 'assets/storytime/story-a.timing.json';
      final strings = _manifestWith(
        id: 'story-a',
        storyText: 'Once upon a time',
        timingAsset: timingAsset,
      );
      strings[timingAsset] = _timingJson([0.0, 0.5, 1.0, 1.5]);

      final service = CuratedTimingService(bundle: _FakeAssetBundle(strings));
      final result = await service.wordStartsFor('unknown-id');

      expect(result, isNull);
    });

    test('caches the result of a prior call for the same cardId', () async {
      const id = 'story-a';
      const timingAsset = 'assets/storytime/story-a.timing.json';
      final strings = _manifestWith(
        id: id,
        storyText: 'Once upon a time',
        timingAsset: timingAsset,
      );
      strings[timingAsset] = _timingJson([0.0, 0.5, 1.0, 1.5]);

      final service = CuratedTimingService(bundle: _FakeAssetBundle(strings));
      final first = await service.wordStartsFor(id);
      final second = await service.wordStartsFor(id);

      expect(first, second);
    });
  });
}
