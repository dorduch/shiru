import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/add_audio_provider.dart';
import 'package:shiru/providers/cards_provider.dart';
import 'package:shiru/services/library_import_service.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/add_audio_screens.dart';

class _FakeCards extends CardsNotifier {
  final added = <AudioCard>[];

  @override
  Future<void> loadCards() async {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> addCard(AudioCard card) async => added.add(card);
}

/// A minimal router that hosts [AddAudioDetailsScreen] and absorbs the
/// post-save navigation to `/parent/stories` so [context.go] doesn't throw.
GoRouter _buildRouter({required Widget home}) => GoRouter(
      initialLocation: '/details',
      routes: [
        GoRoute(
          path: '/details',
          builder: (context, state) => home,
        ),
        GoRoute(
          path: '/parent/stories',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/parent/add-audio',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

void main() {
  testWidgets('details Save builds an uploaded audio card', (tester) async {
    final cards = _FakeCards();
    final router = _buildRouter(home: const AddAudioDetailsScreen());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsProvider.overrideWith((ref) => cards),
          addAudioDraftProvider.overrideWith(
            (ref) => const MediaSelection(
              path: '/tmp/a.m4a',
              mediaType: CardMediaType.audio,
              duration: Duration(seconds: 12),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: StorytimeTheme.day,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Grandma tale');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cards.added, hasLength(1));
    final card = cards.added.single;
    expect(card.title, 'Grandma tale');
    expect(card.storyOrigin, StoryOrigin.uploaded);
    expect(card.mediaType, CardMediaType.audio);
    expect(card.audioPath, '/tmp/a.m4a');
    expect(card.durationMs, 12000);
  });
}
