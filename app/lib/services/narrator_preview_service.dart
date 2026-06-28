import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/storytime_models.dart';

class NarratorPreviewService {
  NarratorPreviewService() {
    // Clear the "playing" badge when a preview finishes on its own.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playing.value = null;
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  /// The narrator whose preview is currently playing, or null when nothing is
  /// playing. Lets the wizard show per-card playback feedback.
  final ValueNotifier<NarratorKey?> playing = ValueNotifier<NarratorKey?>(null);

  String _assetFor(NarratorKey narrator) => switch (narrator) {
    NarratorKey.wizardWally => 'assets/storytime/preview_wizard_wally.wav',
    NarratorKey.fairyFern => 'assets/storytime/preview_fairy_fern.wav',
    NarratorKey.roboRay => 'assets/storytime/preview_robo_ray.wav',
  };

  /// Plays [narrator]'s preview. Tapping the one already playing stops it.
  Future<void> play(NarratorKey narrator) async {
    if (playing.value == narrator) {
      await stop();
      return;
    }
    try {
      // Stop/load BEFORE marking as playing: stopping the previous clip emits a
      // `completed` event that the listener turns into `playing = null`, so set
      // the badge only once that settling is done — otherwise it clears itself.
      await _player.stop();
      await _player.setAsset(_assetFor(narrator));
      await _player.play();
      playing.value = narrator;
    } catch (_) {
      // Surface a failed preview by clearing the badge rather than getting stuck
      // in a perpetual "playing" state.
      if (playing.value == narrator) playing.value = null;
    }
  }

  Future<void> stop() async {
    playing.value = null;
    await _player.stop();
  }

  Future<void> dispose() {
    playing.dispose();
    return _player.dispose();
  }
}
