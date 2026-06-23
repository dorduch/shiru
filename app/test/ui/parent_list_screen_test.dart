import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/category.dart';
import 'package:shiru/providers/cards_provider.dart';
import 'package:shiru/providers/categories_provider.dart';
import 'package:shiru/ui/parent_list_screen.dart';

class _TestCardsNotifier extends CardsNotifier {
  _TestCardsNotifier(this._cards) : super();

  final List<AudioCard> _cards;

  @override
  Future<void> loadCards() async {
    state = AsyncValue.data(_cards);
  }
}

class _TestCategoriesNotifier extends CategoriesNotifier {
  _TestCategoriesNotifier(this._categories) : super();

  final List<Category> _categories;

  @override
  Future<void> loadCategories() async {
    state = AsyncValue.data(_categories);
  }
}

class _ErrorCardsNotifier extends CardsNotifier {
  @override
  Future<void> loadCards() async {
    state = AsyncValue.error(
      StateError('raw database failure'),
      StackTrace.current,
    );
  }
}

Widget _buildScreen({
  required List<AudioCard> cards,
  List<Category> categories = const [],
  bool cardLoadFails = false,
}) {
  return ProviderScope(
    overrides: [
      cardsProvider.overrideWith(
        (ref) =>
            cardLoadFails ? _ErrorCardsNotifier() : _TestCardsNotifier(cards),
      ),
      categoriesProvider.overrideWith(
        (ref) => _TestCategoriesNotifier(categories),
      ),
    ],
    child: const MaterialApp(home: ParentListScreen()),
  );
}

void main() {
  testWidgets('empty state is responsive with one accessible action set', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [390.0, 414.0, 600.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(_buildScreen(cards: const []));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Add your first card'), findsOneWidget);
      expect(
        find.text('Record a story, choose a song, or add a family video.'),
        findsOneWidget,
      );
      expect(find.text('New card'), findsOneWidget);
      expect(find.text('Import multiple'), findsOneWidget);
      expect(find.text('Generate a story'), findsOneWidget);
      expect(find.text('Add Recording'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'overflow at ${width}px');

      expect(
        find.byKey(const ValueKey('library-empty-compact')),
        findsOneWidget,
      );

      for (final label in ['New card', 'Import multiple', 'Generate a story']) {
        final semantics = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        );
        expect(semantics, findsOneWidget);
        expect(tester.getSize(semantics).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(semantics).width, greaterThanOrEqualTo(48));
      }

      if (width == 390) {
        final back = find.byTooltip('Back to player');
        final title = find.text('Library');
        final settings = find.byTooltip('Library settings');
        expect(tester.getCenter(back).dx, lessThan(tester.getCenter(title).dx));
        expect(
          tester.getCenter(title).dx,
          lessThan(tester.getCenter(settings).dx),
        );
        expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(settings).height, greaterThanOrEqualTo(48));
      }

      if (width == 768) {
        final newCard = find.text('New card');
        final import = find.text('Import multiple');
        expect(
          tester.getCenter(newCard).dx,
          lessThan(tester.getCenter(import).dx),
        );
        expect(
          (tester.getCenter(newCard).dx + tester.getCenter(import).dx) / 2,
          closeTo(width / 2, 24),
        );
      }
    }
  });

  testWidgets('renders existing cards with their category labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final category = Category(
      id: 'cat-1',
      name: 'Bedtime',
      emoji: '🌙',
      position: 0,
    );
    final card = AudioCard(
      id: 'card-1',
      collectionId: category.id,
      title: 'Moon Story',
      color: '#F0FDF4',
      audioPath: '/tmp/moon.mp3',
      position: 0,
      createdAt: DateTime(2026, 3, 30).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      _buildScreen(cards: [card], categories: [category]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moon Story'), findsOneWidget);
    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.text('Add your first card'), findsNothing);
    expect(find.text('New card'), findsOneWidget);
    expect(find.text('Import media'), findsOneWidget);
    expect(find.text('Generate story'), findsOneWidget);
  });

  testWidgets('compact populated toolbar keeps every action visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final card = AudioCard(
      id: 'card-1',
      title: 'Moon Story',
      color: '#F0FDF4',
      audioPath: '/tmp/moon.mp3',
      position: 0,
      createdAt: DateTime(2026, 3, 30).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(_buildScreen(cards: [card]));
    await tester.pumpAndSettle();

    for (final label in ['New card', 'Import media', 'Generate story']) {
      final action = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      );
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(action).dx, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(action).dx, lessThanOrEqualTo(390));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide empty state is reserved for landscape layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(_buildScreen(cards: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-empty-wide')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated library exposes category filters', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(768, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final stories = Category(
      id: 'default-stories',
      name: 'Stories',
      emoji: '📖',
      position: 0,
    );
    final songs = Category(
      id: 'default-songs',
      name: 'Songs',
      emoji: '🎵',
      position: 1,
    );
    final card = AudioCard(
      id: 'card-1',
      collectionId: stories.id,
      title: 'Moon Story',
      color: '#F0FDF4',
      audioPath: '/tmp/moon.mp3',
      position: 0,
      createdAt: DateTime(2026, 3, 30).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      _buildScreen(cards: [card], categories: [stories, songs]),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('📖 Stories'), findsOneWidget);
    expect(find.text('🎵 Songs'), findsOneWidget);

    await tester.tap(find.text('🎵 Songs'));
    await tester.pump();
    expect(find.text('No cards in Songs yet'), findsOneWidget);
    expect(find.text('Show all cards'), findsOneWidget);
  });

  testWidgets('load failure is recoverable without exposing raw errors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildScreen(cards: const [], cardLoadFails: true));
    await tester.pump();

    expect(find.text("Couldn't load your library"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('raw database failure'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings menu keeps about as the last entry', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildScreen(cards: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Library settings'));
    await tester.pumpAndSettle();

    final changePin = find.text('Change PIN');
    final categories = find.text('Categories');
    final about = find.text('About Shiru');

    expect(changePin, findsOneWidget);
    expect(categories, findsOneWidget);
    expect(about, findsOneWidget);
    expect(
      tester.getTopLeft(changePin).dy,
      lessThan(tester.getTopLeft(categories).dy),
    );
    expect(
      tester.getTopLeft(categories).dy,
      lessThan(tester.getTopLeft(about).dy),
    );
  });

  testWidgets('labels video cards without replacing their artwork', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final card = AudioCard(
      id: 'video-1',
      title: 'Family Movie',
      color: '#F0FDF4',
      audioPath: '/tmp/family.mp4',
      mediaType: CardMediaType.video,
      position: 0,
      createdAt: DateTime(2026, 6, 22).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(_buildScreen(cards: [card]));
    await tester.pumpAndSettle();

    expect(find.text('Family Movie'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Video',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Preview Family Movie',
      ),
      findsOneWidget,
    );
  });

  testWidgets('asks for confirmation before deleting a card', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final card = AudioCard(
      id: 'card-1',
      title: 'Moon Story',
      color: '#F0FDF4',
      audioPath: '/tmp/moon.mp3',
      position: 0,
      createdAt: DateTime(2026, 3, 30).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(_buildScreen(cards: [card]));
    await tester.pumpAndSettle();

    final deleteAction = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Delete Moon Story',
    );
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Delete card?'), findsOneWidget);
    expect(
      find.text('“Moon Story” will be removed from this device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Moon Story'), findsOneWidget);
  });
}
