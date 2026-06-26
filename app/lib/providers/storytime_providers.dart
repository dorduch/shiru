import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/family_voice.dart';
import '../models/storytime_models.dart';
import '../services/auth_repository.dart';
import '../services/child_profile_service.dart';
import '../services/key_value_store.dart';
import '../services/story_generation_repository.dart';
import '../services/active_story_job_service.dart';
import '../services/audio_label_service.dart';
import '../services/narrator_preview_service.dart';
import '../services/diagnostics_preferences_service.dart';
import '../services/voice_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final childProfileServiceProvider = Provider<ChildProfileService>(
  (ref) => ChildProfileService(ref.watch(keyValueStoreProvider)),
);

final storyGenerationRepositoryProvider = Provider<StoryGenerationRepository>(
  (ref) => FirebaseStoryGenerationRepository(),
);

final activeStoryJobServiceProvider = Provider<ActiveStoryJobService>(
  (ref) => ActiveStoryJobService(ref.watch(keyValueStoreProvider)),
);

final audioLabelServiceProvider = Provider<AudioLabelService>((ref) {
  final service = AudioLabelService();
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

final narratorPreviewServiceProvider = Provider<NarratorPreviewService>((ref) {
  final service = NarratorPreviewService();
  ref.onDispose(service.dispose);
  return service;
});

final diagnosticsPreferencesServiceProvider =
    Provider<DiagnosticsPreferencesService>(
      (ref) => DiagnosticsPreferencesService(),
    );

final childProfileProvider = FutureProvider<ChildProfile?>((ref) async {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) return null;
  return ref.watch(childProfileServiceProvider).load(user.uid);
});

class StoryDraftNotifier extends StateNotifier<StoryDraft> {
  StoryDraftNotifier() : super(const StoryDraft());

  void reset() => state = const StoryDraft();
  void setCharacter(StoryCharacter value) =>
      state = state.copyWith(character: value);
  void setScene(StoryScene value) => state = state.copyWith(scene: value);
  void setTheme(StoryTheme value) => state = state.copyWith(theme: value);
  void setPlot(StoryPlot value) => state = state.copyWith(plot: value);

  /// Select a built-in narrator — clears any previously set family voice.
  void setNarrator(NarratorKey value) =>
      state = state.copyWith(narrator: value, clearFamilyVoiceId: true);

  /// Select a family voice — clears the built-in narrator selection.
  void setFamilyVoice(String voiceId) =>
      state = state.copyWith(familyVoiceId: voiceId, clearNarrator: true);
}

final storyDraftProvider =
    StateNotifierProvider<StoryDraftNotifier, StoryDraft>(
      (ref) => StoryDraftNotifier(),
    );

// ─── Voice cloning ────────────────────────────────────────────────────────────

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => VoiceRepository(),
);

/// Streams the user's family voices; emits [] when unauthenticated.
final familyVoicesProvider = StreamProvider<List<FamilyVoice>>((ref) async* {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }
  yield* ref.watch(voiceRepositoryProvider).watchVoices(user.uid);
});
