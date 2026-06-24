import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/storytime_providers.dart';
import 'package:shiru/theme/storytime_theme.dart';
import 'package:shiru/ui/storytime_screens.dart';
import 'package:shiru/services/audio_label_service.dart';

class _FakeAudioLabelService extends AudioLabelService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String label) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('welcome screen presents both account paths', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: storytimeTheme(),
        home: const StorytimeWelcomeScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Storytime'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('wizard selection is explicit and persists in draft state', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioLabelServiceProvider.overrideWithValue(_FakeAudioLabelService()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: storytimeTheme(),
              home: const StoryWizardScreen(step: 'character'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Who is it about?'), findsOneWidget);
    expect(find.text('Surprise me'), findsOneWidget);
    await tester.tap(find.text('Princess'));
    await tester.pump();

    expect(
      container.read(storyDraftProvider).character,
      StoryCharacter.princess,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
  });
}
