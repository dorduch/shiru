import 'package:just_audio/just_audio.dart';

import '../models/storytime_models.dart';

class NarratorPreviewService {
  final AudioPlayer _player = AudioPlayer();

  String _assetFor(NarratorKey narrator) => switch (narrator) {
    NarratorKey.wizardWally => 'assets/storytime/preview_wizard_wally.wav',
    NarratorKey.fairyFern => 'assets/storytime/preview_fairy_fern.wav',
    NarratorKey.roboRay => 'assets/storytime/preview_robo_ray.wav',
  };

  Future<void> play(NarratorKey narrator) async {
    await _player.stop();
    await _player.setAsset(_assetFor(narrator));
    await _player.play();
  }

  Future<void> dispose() => _player.dispose();
}
