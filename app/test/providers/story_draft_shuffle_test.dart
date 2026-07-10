import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/family_voice.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/storytime_providers.dart';
import 'package:shiru/services/key_value_store.dart';

import '../test_helpers/fake_key_value_store.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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

void main() {
  group('StoryDraftNotifier.shuffleAll', () {
    test(
      'changes all four concept fields and leaves narrator/familyVoiceId '
      'untouched',
      () {
        final notifier = StoryDraftNotifier();
        notifier.setCharacter(StoryCharacter.prince);
        notifier.setScene(StoryScene.castle);
        notifier.setTheme(StoryTheme.friendship);
        notifier.setPlot(StoryPlot.bigWin);
        notifier.setFamilyVoice('grandma-1');

        final before = notifier.state;
        final sentence = notifier.shuffleAll();
        final after = notifier.state;

        expect(after.character, isNot(before.character));
        expect(after.scene, isNot(before.scene));
        expect(after.theme, isNot(before.theme));
        expect(after.plot, isNot(before.plot));
        expect(after.narrator, before.narrator);
        expect(after.familyVoiceId, before.familyVoiceId);
        expect(
          sentence,
          'A story about ${after.character!.label}, ${after.scene!.label}!',
        );
      },
    );

    test('never repeats the prior value for a slot across 100 iterations', () {
      final notifier = StoryDraftNotifier();
      notifier.setCharacter(StoryCharacter.prince);
      notifier.setScene(StoryScene.castle);
      notifier.setTheme(StoryTheme.friendship);
      notifier.setPlot(StoryPlot.bigWin);

      for (var i = 0; i < 100; i++) {
        final before = notifier.state;
        notifier.shuffleAll();
        final after = notifier.state;

        expect(after.character, isNot(before.character));
        expect(after.scene, isNot(before.scene));
        expect(after.theme, isNot(before.theme));
        expect(after.plot, isNot(before.plot));
      }
    });
  });

  group('StoryDraftNotifier.shuffleSlot', () {
    test('re-rolling one slot only changes that slot', () {
      final notifier = StoryDraftNotifier();
      notifier.setCharacter(StoryCharacter.prince);
      notifier.setScene(StoryScene.castle);
      notifier.setTheme(StoryTheme.friendship);
      notifier.setPlot(StoryPlot.bigWin);
      notifier.setNarrator(NarratorKey.fairyFern);

      final before = notifier.state;
      notifier.shuffleSlot(SlotKind.character);
      final after = notifier.state;

      expect(after.character, isNot(before.character));
      expect(after.scene, before.scene);
      expect(after.theme, before.theme);
      expect(after.plot, before.plot);
      expect(after.narrator, before.narrator);
      expect(after.familyVoiceId, before.familyVoiceId);
    });

    test('never repeats the prior value across 100 iterations', () {
      final notifier = StoryDraftNotifier();
      notifier.setScene(StoryScene.castle);

      for (var i = 0; i < 100; i++) {
        final before = notifier.state.scene;
        notifier.shuffleSlot(SlotKind.scene);
        expect(notifier.state.scene, isNot(before));
      }
    });
  });

  group('lastNarratorProvider default resolution', () {
    test('persisted valid built-in wins', () async {
      final store = FakeKeyValueStore({'last_narrator_key': 'roboRay'});
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          familyVoicesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
      );
      addTearDown(container.dispose);

      container.read(lastNarratorProvider);
      await _flushAsync();

      expect(container.read(lastNarratorProvider).value, 'roboRay');
    });

    test('persisted ready family voice wins', () async {
      final store = FakeKeyValueStore({'last_narrator_key': 'family:v1'});
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          familyVoicesProvider.overrideWith(
            (ref) => Stream.value([_voice('v1')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(lastNarratorProvider);
      await _flushAsync();

      expect(container.read(lastNarratorProvider).value, 'family:v1');
    });

    test(
      'persisted family voice that no longer exists falls through to first '
      'ready voice',
      () async {
        final store = FakeKeyValueStore({
          'last_narrator_key': 'family:deleted',
        });
        final container = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            familyVoicesProvider.overrideWith(
              (ref) => Stream.value([_voice('v-ready')]),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(lastNarratorProvider);
        await _flushAsync();

        expect(container.read(lastNarratorProvider).value, 'family:v-ready');
      },
    );

    test(
      'persisted family voice that is not ready falls through to first '
      'ready voice',
      () async {
        final store = FakeKeyValueStore({'last_narrator_key': 'family:v1'});
        final container = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            familyVoicesProvider.overrideWith(
              (ref) => Stream.value([
                _voice('v1', status: FamilyVoiceStatus.cloning),
                _voice('v2'),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(lastNarratorProvider);
        await _flushAsync();

        expect(container.read(lastNarratorProvider).value, 'family:v2');
      },
    );

    test(
      'falls back to wizardWally with no persisted value and no family '
      'voices',
      () async {
        final store = FakeKeyValueStore();
        final container = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            familyVoicesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(lastNarratorProvider);
        await _flushAsync();

        expect(
          container.read(lastNarratorProvider).value,
          NarratorKey.wizardWally.name,
        );
      },
    );

    test(
      'no persisted value falls back to first ready family voice when one '
      'exists',
      () async {
        final store = FakeKeyValueStore();
        final container = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            familyVoicesProvider.overrideWith(
              (ref) => Stream.value([_voice('only-ready')]),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(lastNarratorProvider);
        await _flushAsync();

        expect(
          container.read(lastNarratorProvider).value,
          'family:only-ready',
        );
      },
    );
  });
}
