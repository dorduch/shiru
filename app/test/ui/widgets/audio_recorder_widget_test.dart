import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shiru/models/audio_card.dart';
import 'package:shiru/services/library_import_service.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/widgets/audio_recorder_widget.dart';

void main() {
  Widget buildSubject(AudioRecorderWidget child) {
    return ProviderScope(
      child: MaterialApp(
        // AudioRecorderWidget reads LanternTokens off the ambient Theme (as
        // it does in production, via main.dart's `theme: StorytimeTheme.bedtime`)
        // — without this, `Theme.of(context).extension<LanternTokens>()!`
        // null-checks on the default ThemeData's empty extensions map. Same
        // fix already applied to PinGateScreen's test.
        theme: StorytimeTheme.bedtime,
        home: Scaffold(body: SizedBox(width: 600, child: child)),
      ),
    );
  }

  testWidgets('shows load and record actions for audio and video', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        AudioRecorderWidget(
          onMediaSelected: (_) {},
          retrieveLostData: () async => LostDataResponse(),
        ),
      ),
    );

    expect(find.text('Load from device'), findsOneWidget);
    expect(find.text('Record now'), findsOneWidget);
    expect(find.text('Audio'), findsNWidgets(2));
    expect(find.text('Video'), findsNWidgets(2));
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.video_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('shows video metadata and exposes preview action', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/shiru-video-selector-test.mp4',
    );
    file.writeAsBytesSync(List<int>.filled(1024, 0));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    var previewed = false;
    await tester.pumpWidget(
      buildSubject(
        AudioRecorderWidget(
          currentSelection: MediaSelection(
            path: file.path,
            mediaType: CardMediaType.video,
            duration: const Duration(minutes: 2, seconds: 5),
            sourceName: 'family-movie.mp4',
          ),
          onMediaSelected: (_) {},
          onPreviewVideo: () => previewed = true,
          retrieveLostData: () async => LostDataResponse(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('family-movie.mp4'), findsOneWidget);
    expect(find.textContaining('Video'), findsOneWidget);
    expect(find.textContaining('02:05'), findsOneWidget);
    expect(find.byTooltip('Preview video'), findsOneWidget);

    await tester.tap(find.byTooltip('Preview video'));
    expect(previewed, isTrue);
  });

  testWidgets('routes all four actions and preserves cancellation', (
    tester,
  ) async {
    final videoSources = <ImageSource>[];
    var audioRecordCount = 0;
    var selectedCount = 0;

    await tester.pumpWidget(
      buildSubject(
        AudioRecorderWidget(
          onMediaSelected: (_) => selectedCount += 1,
          pickAudio: () async => null,
          pickVideo: (source) async {
            videoSources.add(source);
            return null;
          },
          startAudioRecording: () async => audioRecordCount += 1,
          restoreSystemUi: () async {},
          retrieveLostData: () async => LostDataResponse(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.audio_file_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.video_file_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.videocam_outlined));
    await tester.pump();

    expect(videoSources, [ImageSource.gallery, ImageSource.camera]);
    expect(audioRecordCount, 1);
    expect(selectedCount, 0);
  });

  testWidgets('recovers an interrupted Android video selection', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/shiru-lost-video.mp4');
    file.writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    MediaSelection? selected;
    await tester.pumpWidget(
      buildSubject(
        AudioRecorderWidget(
          onMediaSelected: (value) => selected = value,
          retrieveLostData: () async => LostDataResponse(
            file: XFile(file.path),
            type: RetrieveType.video,
          ),
          importMedia: (path, mediaType, duration) async => MediaSelection(
            path: path,
            mediaType: mediaType,
            duration: const Duration(seconds: 10),
          ),
          restoreSystemUi: () async {},
        ),
      ),
    );
    for (var i = 0; i < 5 && selected == null; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(selected?.path, file.path);
    expect(selected?.mediaType, CardMediaType.video);
  });
}
