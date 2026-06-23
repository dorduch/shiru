import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/ui/kid_home_screen.dart';

void main() {
  testWidgets('video cards have a visible and accessible media label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final card = AudioCard(
      id: 'video-1',
      title: 'Family Movie',
      color: '#F0FDF4',
      audioPath: '/tmp/family.mp4',
      mediaType: CardMediaType.video,
      position: 0,
      createdAt: DateTime(2026, 6, 22).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 400,
              child: AudioCardTile(
                card: card,
                isPlayingThis: false,
                isPlayingGlobal: false,
                isAnotherPlaying: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VIDEO'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Family Movie, video, tap to watch',
      ),
      findsOneWidget,
    );
  });
}
