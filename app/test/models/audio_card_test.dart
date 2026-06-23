import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';

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
}
