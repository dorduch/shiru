import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  StoryDraftNotifier({Random? random})
    : _random = random ?? Random(),
      super(const StoryDraft());

  final Random _random;

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

  // ─── Shuffle ────────────────────────────────────────────────────────────

  /// Re-rolls a single concept slot, guaranteed to differ from its current
  /// value (when the underlying enum has more than one member). Never
  /// touches `narrator`/`familyVoiceId`.
  void shuffleSlot(SlotKind slot) {
    switch (slot) {
      case SlotKind.character:
        state = state.copyWith(
          character: _rerollDifferent(StoryCharacter.values, state.character),
        );
      case SlotKind.scene:
        state = state.copyWith(
          scene: _rerollDifferent(StoryScene.values, state.scene),
        );
      case SlotKind.theme:
        state = state.copyWith(
          theme: _rerollDifferent(StoryTheme.values, state.theme),
        );
      case SlotKind.plot:
        state = state.copyWith(
          plot: _rerollDifferent(StoryPlot.values, state.plot),
        );
    }
  }

  /// Re-rolls all four concept slots (each guaranteed to differ from its
  /// prior value), leaving `narrator`/`familyVoiceId` untouched, and returns
  /// a TTS-ready sentence describing the new character/scene combo — spec
  /// §3.3: "A story about {character}, {scene}!".
  String shuffleAll() {
    final character = _rerollDifferent(
      StoryCharacter.values,
      state.character,
    );
    final scene = _rerollDifferent(StoryScene.values, state.scene);
    final theme = _rerollDifferent(StoryTheme.values, state.theme);
    final plot = _rerollDifferent(StoryPlot.values, state.plot);
    state = state.copyWith(
      character: character,
      scene: scene,
      theme: theme,
      plot: plot,
    );
    return 'A story about ${character.label}, ${scene.label}!';
  }

  /// Uniform-random pick from [values], re-rolling on collision so the
  /// result never equals [current] — unless [values] has only one member,
  /// in which case that member is returned as-is (no infinite loop).
  T _rerollDifferent<T>(List<T> values, T? current) {
    if (values.length <= 1) return values.first;
    var candidate = values[_random.nextInt(values.length)];
    while (candidate == current) {
      candidate = values[_random.nextInt(values.length)];
    }
    return candidate;
  }
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

// ─── Persisted default narrator ────────────────────────────────────────────

/// Raw persisted value of the last confirmed narrator selection, in the
/// same string format as [StoryDraft.resolvedNarratorKey] (a bare
/// [NarratorKey.name] or `family:<id>`). Mirrors the read/write pattern of
/// `PinNotifier`/`AdultGateNotifier` — a thin [StateNotifier] over
/// [KeyValueStore], exposed as [AsyncValue] while the initial read is
/// in flight.
///
/// Call `ref.read(lastNarratorKeyProvider.notifier).save(key)` whenever the
/// Composer confirms a narrator selection.
class LastNarratorKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  static const _key = 'last_narrator_key';
  final KeyValueStore _storage;

  LastNarratorKeyNotifier(this._storage) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _storage.read(key: _key);
      state = AsyncValue.data(value);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Persists [narratorKey] as the new default narrator. [narratorKey] must
  /// already be in [StoryDraft.resolvedNarratorKey] format.
  Future<void> save(String narratorKey) async {
    await _storage.write(key: _key, value: narratorKey);
    state = AsyncValue.data(narratorKey);
  }
}

final lastNarratorKeyProvider =
    StateNotifierProvider<LastNarratorKeyNotifier, AsyncValue<String?>>(
      (ref) => LastNarratorKeyNotifier(ref.watch(keyValueStoreProvider)),
    );

/// The default narrator to preselect on Composer entry, resolved (spec
/// §2.2) as:
///
/// 1. The persisted [lastNarratorKeyProvider] value, if still valid — a
///    `family:<id>` value is valid only while that [FamilyVoice] still
///    exists and is [FamilyVoiceStatus.ready]; a bare [NarratorKey] name is
///    always valid (built-ins are never deleted).
/// 2. Else, the first [FamilyVoiceStatus.ready] voice in
///    [familyVoicesProvider], if any exist.
/// 3. Else, [NarratorKey.wizardWally].
///
/// The result is a string in [StoryDraft.resolvedNarratorKey] format (a bare
/// [NarratorKey.name] or `family:<id>`) — never null, never throws.
final lastNarratorProvider = Provider<AsyncValue<String>>((ref) {
  final persisted = ref.watch(lastNarratorKeyProvider);
  final familyVoices = ref.watch(familyVoicesProvider);

  // The persisted-key read is the only source that can legitimately still be
  // loading; a slow/errored family-voices stream just degrades to "no family
  // voices yet" rather than blocking resolution.
  final readyVoices = familyVoices.asData?.value ?? const <FamilyVoice>[];

  return persisted.when(
    data: (persistedKey) =>
        AsyncValue.data(_resolveDefaultNarrator(persistedKey, readyVoices)),
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.data(
      _resolveDefaultNarrator(null, readyVoices),
    ),
  );
});

// ─── Daily story allowance (quota) visibility ──────────────────────────────
//
// Spec §2.1: the daily allowance is enforced server-side (`createStoryJob` in
// functions/src/index.ts), but a parent/child should be able to see how many
// stories are left *before* they hit zero — including before the first job
// of the day, when the only client-known number (`CreateStoryJobResult
// .remaining`) hasn't been fetched yet. These providers read the same
// Firestore documents the backend writes/reads.

/// UTC calendar-day key, e.g. `2026-07-12` — must match the backend's
/// `utcQuotaDay()` (`functions/src/domain.ts`: `date.toISOString().slice(0,
/// 10)`), since both sides key `generationUsage` docs by this string.
String _utcQuotaDay([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10);

/// Today's already-reserved story count, read live from
/// `users/{uid}/generationUsage/{utcDay}` (Firestore rules permit
/// user-scoped reads here — `firestore.rules`: `allow read: if owns(uid)`).
/// Firestore's own snapshot stream means this updates the moment
/// `createStoryJob` reserves a unit server-side, so no extra plumbing from
/// `CreateStoryJobResult.remaining` is needed to keep it fresh mid-session.
final _generationUsageProvider = StreamProvider.autoDispose<int>((ref) async* {
  final user = await ref.watch(authUserProvider.future);
  if (user == null) {
    yield 0;
    return;
  }
  final day = _utcQuotaDay();
  final doc = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('generationUsage')
      .doc(day);
  yield* doc.snapshots().map(
    (snap) => (snap.data()?['reserved'] as num?)?.toInt() ?? 0,
  );
});

/// Configured daily story allowance, from `storytimeConfig/generation`
/// (`dailyQuota`, legacy `dailyLimit` fallback — mirrors the backend's own
/// fallback chain in `functions/src/index.ts`).
///
/// `firestore.rules` currently denies client reads of `storytimeConfig/*`
/// (`allow read, write: if false`), so a permission-denied error here
/// quietly degrades to the backend's own hardcoded default (10) rather than
/// surfacing an error UI — this indicator is a soft nicety, not something
/// worth a loading spinner or retry control over. Once the rule is opened to
/// authenticated reads, this starts reflecting the real configured value
/// with no client-side change needed.
final _dailyQuotaProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final snap = await FirebaseFirestore.instance
        .doc('storytimeConfig/generation')
        .get();
    final data = snap.data();
    final quota = (data?['dailyQuota'] as num?) ?? (data?['dailyLimit'] as num?);
    return quota?.toInt() ?? 10;
  } catch (_) {
    return 10;
  }
});

/// Stories left today — the configured allowance minus today's reserved
/// count. Null while either input is still resolving; callers should treat
/// null as "don't show the indicator yet", not as zero.
final remainingStoriesTodayProvider = Provider.autoDispose<int?>((ref) {
  final usage = ref.watch(_generationUsageProvider).valueOrNull;
  final quota = ref.watch(_dailyQuotaProvider).valueOrNull;
  if (usage == null || quota == null) return null;
  final remaining = quota - usage;
  return remaining < 0 ? 0 : remaining;
});

String _resolveDefaultNarrator(
  String? persistedKey,
  List<FamilyVoice> familyVoices,
) {
  if (persistedKey != null && persistedKey.isNotEmpty) {
    if (persistedKey.startsWith('family:')) {
      final id = persistedKey.substring('family:'.length);
      final stillReady = familyVoices.any(
        (voice) => voice.id == id && voice.status == FamilyVoiceStatus.ready,
      );
      if (stillReady) return persistedKey;
      // Deleted or no longer ready — fall through to the next rule.
    } else if (NarratorKey.values.any((n) => n.name == persistedKey)) {
      // Built-ins are never deleted — always valid.
      return persistedKey;
    }
    // Unrecognized value (shouldn't happen) — fall through defensively.
  }

  for (final voice in familyVoices) {
    if (voice.status == FamilyVoiceStatus.ready) return voice.narratorKey;
  }

  return NarratorKey.wizardWally.name;
}
