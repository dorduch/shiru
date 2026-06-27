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
  final updated = <AudioCard>[];

  @override
  Future<void> loadCards() async {
    // Keep whatever was seeded; don't reset to empty.
    if (state is! AsyncData) {
      state = const AsyncValue.data([]);
    }
  }

  /// Populate the in-memory state with [cards] so edit mode can find them.
  void seed(List<AudioCard> cards) {
    state = AsyncValue.data(List.unmodifiable(cards));
  }

  @override
  Future<void> addCard(AudioCard card) async => added.add(card);

  @override
  Future<void> updateCard(AudioCard card) async => updated.add(card);
}

/// A minimal router that hosts [AddAudioDetailsScreen] and absorbs the
/// post-save navigation to `/parent/stories` so [context.go] doesn't throw.
GoRouter _buildRouter({required Widget home, String initialLocation = '/details'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/details',
          builder: (context, state) => home,
        ),
        GoRoute(
          path: '/edit/:id',
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

  testWidgets('edit mode updates title/color via updateCard', (tester) async {
    final existing = AudioCard(
      id: 'c1',
      title: 'Old',
      color: 'E6A487',
      audioPath: '/old.m4a',
      storyOrigin: StoryOrigin.uploaded,
      durationMs: 5000,
      position: 0,
      createdAt: 1,
    );
    final cards = _FakeCards()..seed([existing]);
    // No addAudioDraftProvider override → draft is null (no audio replacement)
    final router = _buildRouter(
      home: const AddAudioDetailsScreen(editingCardId: 'c1'),
      initialLocation: '/edit/c1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsProvider.overrideWith((ref) => cards),
        ],
        child: MaterialApp.router(
          theme: StorytimeTheme.day,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cards.updated.single.id, 'c1');
    expect(cards.updated.single.title, 'New name');
    expect(cards.updated.single.audioPath, '/old.m4a'); // unchanged when not replaced
  });
}
