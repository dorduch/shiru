// Widget/screen-level tests for the Story Composer (Task 9 of
// docs/superpowers/plans/2026-07-10-story-composer.md).
//
// `test/providers/story_draft_shuffle_test.dart` already covers default-
// narrator resolution (persisted → ready family → Wally, incl. the
// deleted/not-ready fallback) and raw `shuffleAll`/`shuffleSlot` semantics at
// the provider level — none of that is repeated here. This file focuses on
// what that file can't: screen/widget-level rendering and interaction, plus a
// backend-contract regression guard on `StoryDraft.toRequestJson()`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/family_voice.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/storytime_providers.dart';
import 'package:shiru/services/audio_label_service.dart';
import 'package:shiru/services/key_value_store.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/story_composer_screen.dart';
import 'package:shiru/ui/story_slot_sheet.dart';
import 'package:shiru/ui/widgets/lantern/lantern.dart';

import 'test_helpers/fake_key_value_store.dart';

/// No-op [AudioLabelService] double so widget tests never reach the real
/// `flutter_tts` platform channel (unavailable/unmocked under `flutter_test`,
/// and irrelevant to what these tests assert).
class _FakeAudioLabelService extends AudioLabelService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String label) async {
    spoken.add(label);
  }
}

FamilyVoice _voice(
  String id, {
  FamilyVoiceStatus status = FamilyVoiceStatus.ready,
}) {
  return FamilyVoice(
    id: id,
    name: 'Voice $id',
    relationship: 'Grandma',
    subjectLiving: true,
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Builds a [ProviderContainer] wired the same way every Composer/Sheet test
/// needs: a fake key/value store (so `lastNarratorKeyProvider` never touches
/// real storage), a directly-overridden `familyVoicesProvider` stream (the
/// same pattern `story_draft_shuffle_test.dart` already uses, bypassing
/// `authUserProvider`/Firebase entirely), and the fake TTS double above.
ProviderContainer _buildContainer({List<FamilyVoice> familyVoices = const []}) {
  return ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(FakeKeyValueStore()),
      familyVoicesProvider.overrideWith((ref) => Stream.value(familyVoices)),
      audioLabelServiceProvider.overrideWithValue(_FakeAudioLabelService()),
    ],
  );
}

void main() {
  group('StoryComposerScreen layout order', () {
    testWidgets(
      'renders the Voice Shelf above the story slot grid, in both widget '
      'position and section-label order',
      (tester) async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StoryComposerScreen()),
          ),
        );
        // No family voices means no processing shimmer anywhere in this
        // tree, so every animation in view (AnimatedSwitcher slot reveal,
        // GlowButton press scale) is one-shot/finite — pumpAndSettle is safe.
        await tester.pumpAndSettle();

        expect(find.byType(VoiceCard), findsWidgets);
        expect(find.byType(StorySlot), findsWidgets);

        final shelfTop = tester.getTopLeft(find.byType(VoiceCard).first).dy;
        final slotTop = tester.getTopLeft(find.byType(StorySlot).first).dy;
        expect(
          shelfTop,
          lessThan(slotTop),
          reason: 'Voice Shelf cards must sit above the story slot grid',
        );

        final shelfLabelTop = tester
            .getTopLeft(find.text("WHO'S READING TONIGHT?"))
            .dy;
        final storyLabelTop = tester.getTopLeft(find.text('THE STORY')).dy;
        expect(
          shelfLabelTop,
          lessThan(storyLabelTop),
          reason:
              '"Who\'s reading tonight?" section must precede "The story" '
              'section — narrator-first applies to visual order too',
        );
      },
    );
  });

  group('VoiceCard processing state', () {
    testWidgets(
      'is non-tappable and exposes Semantics(enabled: false)',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: StorytimeTheme.bedtime,
            home: Scaffold(
              body: VoiceCard(
                name: 'Grandma',
                subline: 'Grandma',
                glyph: const FamilyVoiceGlyph(),
                variant: VoiceCardVariant.processing,
                selected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        // The processing well runs a repeating (never-completing) shimmer
        // AnimationController — pumpAndSettle would hang. A couple of bounded
        // pumps is enough to reach steady state without waiting it out.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // `warnIfMissed: false` — the whole point of this assertion is that
        // the tap does *not* hit test (IgnorePointer), so the framework's
        // "didn't hit anything" warning is expected, not a bug.
        await tester.tap(find.byType(VoiceCard), warnIfMissed: false);
        await tester.pump();
        expect(
          tapped,
          isFalse,
          reason: 'a processing card must swallow taps (IgnorePointer)',
        );

        expect(
          tester.getSemantics(find.byType(VoiceCard)),
          // `containsSemantics` (unlike `matchesSemantics`) only checks the
          // fields given — VoiceCard's Semantics node also carries
          // button/selected/label, which aren't this test's concern.
          containsSemantics(hasEnabledState: true, isEnabled: false),
          reason:
              'processing must explicitly declare an enabled state and be '
              'announced as unavailable/disabled',
        );
      },
    );
  });

  group('VoiceTeaser visibility', () {
    testWidgets('present when no family voices exist', (tester) async {
      final container = _buildContainer(familyVoices: const []);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StoryComposerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceTeaser), findsOneWidget);
    });

    testWidgets('absent once a ready family voice exists', (tester) async {
      final container = _buildContainer(familyVoices: [_voice('v1')]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StoryComposerScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceTeaser), findsNothing);
    });

    testWidgets('absent while a family voice is only processing', (
      tester,
    ) async {
      final container = _buildContainer(
        familyVoices: [_voice('v1', status: FamilyVoiceStatus.cloning)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StoryComposerScreen()),
        ),
      );
      // A processing voice renders the repeating shimmer well from
      // VoiceCard's `_ProcessingGlyphWell` — never settles, so avoid
      // pumpAndSettle here; bounded pumps are enough for the tree (incl. the
      // fresh-draft shuffle + default-narrator post-frame callbacks) to
      // stabilize.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(VoiceTeaser), findsNothing);
    });
  });

  group('StorySlotSheet selection', () {
    testWidgets(
      'tapping an option tile updates storyDraftProvider and dismisses the '
      'sheet',
      (tester) async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          const StorySlotSheet(slot: SlotKind.character),
                    ),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(container.read(storyDraftProvider).character, isNull);

        await tester.tap(find.text('open sheet'));
        // The modal route's enter transition is a finite Material animation
        // (no repeating tickers involved yet) — safe to settle.
        await tester.pumpAndSettle();
        expect(find.byType(StorySlotSheet), findsOneWidget);

        await tester.tap(find.text('Princess'));
        // `_select` applies the provider update synchronously (before
        // scheduling the dismiss), so a single pump is enough to observe it.
        await tester.pump();
        expect(
          container.read(storyDraftProvider).character,
          StoryCharacter.princess,
        );
        expect(
          find.byType(StorySlotSheet),
          findsOneWidget,
          reason: 'the sheet auto-dismisses after a 250ms delay, not instantly',
        );

        // Per the task notes: prefer one large explicit pump sized past all
        // known delays (the 250ms `_scheduleDismiss` timer) over relying on
        // pumpAndSettle alone, which is what surfaced flakiness for a prior
        // agent around this same screen's staggered shuffle animation.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byType(StorySlotSheet), findsNothing);
      },
    );
  });

  group('StoryDraft.toRequestJson backend contract', () {
    test('built-in narrator payload shape is exact', () {
      const draft = StoryDraft(
        character: StoryCharacter.firefighter,
        scene: StoryScene.underTheSea,
        theme: StoryTheme.kindness,
        plot: StoryPlot.treasureHunt,
        narrator: NarratorKey.fairyFern,
      );

      expect(draft.toRequestJson(), {
        'character': 'firefighter',
        'scene': 'underTheSea',
        'theme': 'kindness',
        'plot': 'treasureHunt',
        'narratorKey': 'fairyFern',
      });
    });

    test('family-voice narrator payload shape is exact', () {
      const draft = StoryDraft(
        character: StoryCharacter.prince,
        scene: StoryScene.castle,
        theme: StoryTheme.bravery,
        plot: StoryPlot.bigWin,
        familyVoiceId: 'grandma-42',
      );

      expect(draft.toRequestJson(), {
        'character': 'prince',
        'scene': 'castle',
        'theme': 'bravery',
        'plot': 'bigWin',
        'narratorKey': 'family:grandma-42',
      });
    });
  });
}
