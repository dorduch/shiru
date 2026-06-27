import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/models/story_origin_label.dart';

void main() {
  test('subtitle maps every origin', () {
    expect(storyOriginSubtitle(StoryOrigin.curated), 'Ready-made');
    expect(storyOriginSubtitle(StoryOrigin.uploaded), 'Your audio');
    expect(storyOriginSubtitle(StoryOrigin.generated), 'Your story');
  });

  test('semantics phrase maps every origin', () {
    expect(storyOriginSemantics(StoryOrigin.curated), 'ready-made story');
    expect(storyOriginSemantics(StoryOrigin.uploaded), 'your audio');
    expect(storyOriginSemantics(StoryOrigin.generated), 'your story');
  });
}
