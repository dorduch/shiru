# Shiru

Shiru is a local-first Flutter audio and video player for kids. Parents create
visual cards from media already on the device or record new audio and video;
children tap a card to listen or watch in a focused player.

The application is implemented in `app/`. It uses Riverpod for state,
`just_audio` and `video_player` for playback, encrypted SQLite persistence, and
a custom `PixelSprite` renderer for animated pixel art.

## Supported media

- Audio: MP3, M4A, WAV, and AAC, up to 200 MB per file.
- Video: MP4, MOV, and M4V, up to 15 minutes and 1 GB per file.
- Video codecs still depend on native Android/iOS playback support. Shiru
  validates a video with the platform player before copying it into the local
  library.
- Media and card metadata stay in app-private local storage. There is no Shiru
  account, backend, cloud library, transcoding, or compression.

Video selection and recording use the operating system's gallery and camera
flows. iOS displays camera, photo-library, and microphone permission prompts as
needed. Android uses system intents for gallery/camera access and does not add
storage or camera permissions; audio recording still requests microphone
access.

## Development

```sh
cd app
flutter pub get
flutter run
flutter analyze
flutter test
```

See `app/RELEASE.md` for release builds and the physical-device verification
matrix.
