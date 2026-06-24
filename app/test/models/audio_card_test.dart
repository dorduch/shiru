import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/models/storytime_models.dart';

void main() {
  AudioCard buildCard({CardMediaType mediaType = CardMediaType.audio}) {
    return AudioCard(
      id: 'card-1',
      title: 'Story',
      color: '#FFFFFF',
      audioPath: '/library/story.mp4',
      mediaType: mediaType,
      position: 0,
      createdAt: 123,
    );
  }

  test('legacy maps without media_type default to audio', () {
    final map = buildCard().toMap()..remove('media_type');

    expect(AudioCard.fromMap(map).mediaType, CardMediaType.audio);
  });

  test('video media type round trips through persistence map', () {
    final card = buildCard(mediaType: CardMediaType.video);
    final restored = AudioCard.fromMap(card.toMap());

    expect(restored.mediaType, CardMediaType.video);
    expect(restored.mediaPath, card.audioPath);
    expect(restored.toMap()['audio_path'], card.audioPath);
  });

  test('copyWith retains and can replace media type', () {
    final video = buildCard().copyWith(mediaType: CardMediaType.video);

    expect(video.mediaType, CardMediaType.video);
    expect(video.copyWith().mediaType, CardMediaType.video);
  });

  test('Storytime metadata round trips through persistence map', () {
    final card = buildCard().copyWith(
      storyOrigin: StoryOrigin.curated,
      narratorKey: NarratorKey.fairyFern,
      isFavorite: true,
      durationMs: 120000,
      lastPlayedAt: 456,
      playbackPosition: 30000,
    );

    final restored = AudioCard.fromMap(card.toMap());

    expect(restored.storyOrigin, StoryOrigin.curated);
    expect(restored.narratorKey, NarratorKey.fairyFern);
    expect(restored.isFavorite, isTrue);
    expect(restored.durationMs, 120000);
    expect(restored.lastPlayedAt, 456);
    expect(restored.playbackPosition, 30000);
  });
}
