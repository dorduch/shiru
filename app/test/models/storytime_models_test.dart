import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/storytime_models.dart';

void main() {
  test('age bands map to increasing story lengths', () {
    expect(AgeBand.early.targetWordCount, 350);
    expect(AgeBand.middle.targetWordCount, 550);
    expect(AgeBand.older.targetWordCount, 800);
  });

  test('a complete draft serializes only allowlisted choice keys', () {
    final draft = StoryDraft(
      character: StoryCharacter.princess,
      scene: StoryScene.forest,
      theme: StoryTheme.kindness,
      plot: StoryPlot.surpriseFriend,
      narrator: NarratorKey.fairyFern,
    );

    expect(draft.isComplete, isTrue);
    expect(draft.toRequestJson(), {
      'character': 'princess',
      'scene': 'forest',
      'theme': 'kindness',
      'plot': 'surpriseFriend',
      'narratorKey': 'fairyFern',
    });
  });

  test('child profile round trips without an account field', () {
    const profile = ChildProfile(
      name: 'Sunny',
      ageBand: AgeBand.middle,
      avatarSpriteKey: 'kid_1',
    );

    expect(ChildProfile.fromJson(profile.toJson()).name, 'Sunny');
    expect(profile.toJson().keys, {'name', 'ageBand', 'avatarSpriteKey'});
  });
}
