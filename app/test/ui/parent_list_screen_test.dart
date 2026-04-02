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

Widget _buildScreen({
  required List<AudioCard> cards,
  List<Category> categories = const [],
}) {
  return ProviderScope(
    overrides: [
      cardsProvider.overrideWith((ref) => _TestCardsNotifier(cards)),
      categoriesProvider.overrideWith(
        (ref) => _TestCategoriesNotifier(categories),
      ),
    ],
    child: const MaterialApp(home: ParentListScreen()),
  );
}

void main() {
  testWidgets('empty state only shows the v1 actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildScreen(cards: const []));
    await tester.pumpAndSettle();

    expect(find.text('Start with one goodnight message'), findsOneWidget);
    expect(find.text('Add Recording'), findsNWidgets(2));
    expect(find.text('Import Audio'), findsNWidgets(2));
    expect(find.text('Voices'), findsNothing);
    expect(find.text('Story Builder'), findsNothing);
  });

  testWidgets('renders existing cards with their category labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text('🌙 Bedtime'), findsOneWidget);
    expect(find.text('Start with one goodnight message'), findsNothing);
  });

  testWidgets('settings menu keeps about as the last entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
}
