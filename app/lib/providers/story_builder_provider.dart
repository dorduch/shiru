import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_card.dart';
import '../models/story_builder_state.dart';
import '../services/story_builder_service.dart';
import '../services/audio_service.dart';
import 'cards_provider.dart';

class StoryBuilderNotifier extends StateNotifier<StoryBuilderState> {
  final Ref ref;

  StoryBuilderNotifier(this.ref) : super(const StoryBuilderState());

  void selectHero(String heroId) {
    state = state.copyWith(
      selectedHero: heroId,
      step: StoryBuilderStep.themeSelection,
    );
  }

  void selectTheme(String themeId) {
    state = state.copyWith(
      selectedTheme: themeId,
      step: StoryBuilderStep.voiceSelection,
    );
  }

  void selectVoice(String voiceId) {
    state = state.copyWith(
      selectedVoiceId: voiceId,
      step: StoryBuilderStep.lengthSelection,
    );
  }

  void selectLength(StoryLength length) {
    state = state.copyWith(selectedLength: length);
    _generate();
  }

  void goBack() {
    switch (state.step) {
      case StoryBuilderStep.themeSelection:
        state = state.copyWith(step: StoryBuilderStep.heroSelection);
      case StoryBuilderStep.voiceSelection:
        state = state.copyWith(step: StoryBuilderStep.themeSelection);
      case StoryBuilderStep.lengthSelection:
        state = state.copyWith(step: StoryBuilderStep.voiceSelection);
      default:
        break;
    }
  }

  void reset() {
    state = const StoryBuilderState();
  }

  Future<void> _generate() async {
    try {
      state = state.copyWith(
        step: StoryBuilderStep.generating,
        progress: 0.0,
      );

      final story = await StoryBuilderService.generateStory(
        hero: state.selectedHero!,
        theme: state.selectedTheme!,
        length: state.selectedLength!,
      );
      state = state.copyWith(generatedStoryText: story.text, progress: 0.5);

      final audioPath = await StoryBuilderService.generateAudio(story.text, voiceId: state.selectedVoiceId!);
      state = state.copyWith(generatedAudioPath: audioPath, progress: 0.9);

      final heroLabel = storyHeroes
          .firstWhere((h) => h['id'] == state.selectedHero)['label']!;
      final themeLabel = storyThemes
          .firstWhere((t) => t['id'] == state.selectedTheme)['label']!;
      final color = heroColors[state.selectedHero] ?? '#E0E7FF';

      final cards = ref.read(cardsProvider).valueOrNull ?? [];
      final card = AudioCard(
        id: const Uuid().v4(),
        title: story.title.isNotEmpty ? story.title : '$heroLabel - $themeLabel',
        color: color,
        audioPath: audioPath,
        position: cards.length,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(cardsProvider.notifier).addCard(card);
      state = state.copyWith(progress: 1.0, step: StoryBuilderStep.done);

      ref.read(audioServiceProvider).playCard(card);
    } catch (e) {
      debugPrint('Story generation error: $e');
      state = state.copyWith(
        step: StoryBuilderStep.error,
        errorMessage: 'An error occurred while creating the story. Please try again.',
      );
    }
  }
}

final storyBuilderProvider =
    StateNotifierProvider.autoDispose<StoryBuilderNotifier, StoryBuilderState>(
  (ref) => StoryBuilderNotifier(ref),
);

/// Fetches Cartesia stock voices once and caches for the app session.
final stockVoicesProvider = FutureProvider<List<Map<String, String>>>((ref) {
  ref.keepAlive();
  return StoryBuilderService.loadStockVoices();
});
