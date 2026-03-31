import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_card.dart';
import '../providers/audio_player_provider.dart';

class AudioService {
  final Ref ref;
  late final AudioPlayer _player;

  AudioService(this.ref) {
    _player = ref.read(audioPlayerProvider);
    _player.playerStateStream.listen((state) {
      ref.read(isPlayingProvider.notifier).state = state.playing;
      if (state.processingState == ProcessingState.completed) {
        ref.read(currentPlayingCardIdProvider.notifier).state = null;
      }
    });
  }

  Future<void> playCard(AudioCard card) async {
    final currentlyPlaying = ref.read(currentPlayingCardIdProvider);
    if (currentlyPlaying == card.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    try {
      await _player.stop();
      ref.read(currentPlayingCardIdProvider.notifier).state = card.id;
      await _player.setFilePath(card.audioPath);
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    ref.read(currentPlayingCardIdProvider.notifier).state = null;
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(ref);
});
