import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/cards_provider.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/storytime_screens.dart';

AudioCard _card(String id, String title, StoryOrigin origin) => AudioCard(
      id: id,
      title: title,
      color: 'E6A487',
      audioPath: '/x.m4a',
      storyOrigin: origin,
      position: 0,
      createdAt: 0,
    );

class _StubCards extends CardsNotifier {
  _StubCards(this._cards);
  final List<AudioCard> _cards;

  @override
  Future<void> loadCards() async {
    state = AsyncValue.data(_cards);
  }
}

/// Minimal router that hosts [StoryLibraryScreen] and absorbs navigation to
/// '/home' and '/story/:id' so [context.go] doesn't throw.
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/listen',
      routes: [
        GoRoute(
          path: '/listen',
          builder: (context, state) => const StoryLibraryScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/story/:id',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

void main() {
  testWidgets(
    'kid Listen badges non-default origins as "Made by you" and drops the '
    'per-tile origin sublabel for curated stories',
    (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cardsProvider.overrideWith(
            (ref) => _StubCards([
              _card('1', 'Fox', StoryOrigin.generated),
              _card('2', 'Gran', StoryOrigin.uploaded),
              _card('3', 'Old Favorite', StoryOrigin.curated),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: StorytimeTheme.day,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      // Non-default origins (generated, uploaded) get the badge...
      expect(find.text('Made by you'), findsNWidgets(2));
      // ...but the curated tile (the default origin) gets no sublabel at
      // all — the old "Ready-made" repeated on every tile is gone.
      expect(find.text('Ready-made'), findsNothing);
      expect(find.text('Your story'), findsNothing);
      expect(find.text('Your audio'), findsNothing);
    },
  );
}
