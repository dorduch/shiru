import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/ui/pixel_sprite.dart';
import 'package:shiru/ui/widgets/storytime/story_avatar.dart';

AudioCard _card({
  String? spriteKey,
  StoryOrigin origin = StoryOrigin.curated,
}) =>
    AudioCard(
      id: 'c1',
      title: 'A Story',
      color: 'E6A487',
      audioPath: '/x.m4a',
      spriteKey: spriteKey,
      storyOrigin: origin,
      position: 0,
      createdAt: 0,
    );

Future<void> _pump(WidgetTester tester, AudioCard card) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: StoryAvatar(card: card))),
  );
}

void main() {
  testWidgets('renders the concept SVG glyph when spriteKey names a drawn icon',
      (tester) async {
    await _pump(tester, _card(spriteKey: 'animalFriend'));

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(PixelSprite), findsNothing);
  });

  testWidgets('falls back to a pixel sprite for a non-concept sprite key',
      (tester) async {
    await _pump(tester, _card(spriteKey: 'moon'));

    expect(find.byType(PixelSprite), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('falls back to a pixel sprite when spriteKey is null',
      (tester) async {
    await _pump(tester, _card());

    expect(find.byType(PixelSprite), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('non-curated cards keep the pixel sprite even with a concept key',
      (tester) async {
    await _pump(
      tester,
      _card(spriteKey: 'animalFriend', origin: StoryOrigin.generated),
    );

    expect(find.byType(PixelSprite), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });
}
