import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/services/starter_story_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starter pack contains six playable bundled audio assets', () async {
    final manifest =
        jsonDecode(
              await rootBundle.loadString(StarterStoryService.manifestAsset),
            )
            as List<dynamic>;

    expect(manifest, hasLength(6));
    for (final entry in manifest.cast<Map<dynamic, dynamic>>()) {
      final audio = await rootBundle.load(entry['audioAsset'] as String);
      expect(
        audio.lengthInBytes,
        greaterThan(4096),
        reason: entry['title'] as String,
      );
    }
  });
}
