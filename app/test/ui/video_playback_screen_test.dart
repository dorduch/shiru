import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/providers/audio_player_provider.dart';
import 'package:shiru/ui/video_playback_screen.dart';

class _FakeVideoController implements VideoPlaybackController {
  _FakeVideoController({this.initializeError});

  final Object? initializeError;
  final List<VoidCallback> _listeners = [];
  bool disposed = false;
  int pauseCount = 0;

  VideoPlaybackSnapshot _value = const VideoPlaybackSnapshot(
    isInitialized: false,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    aspectRatio: 16 / 9,
    hasError: false,
  );

  @override
  VideoPlaybackSnapshot get value => _value;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Widget buildView() => const ColoredBox(
    key: ValueKey('fake-video-view'),
    color: Color(0xFF334155),
  );

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> initialize() async {
    if (initializeError != null) throw initializeError!;
    _value = const VideoPlaybackSnapshot(
      isInitialized: true,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration(minutes: 2),
      aspectRatio: 16 / 9,
      hasError: false,
    );
    _notify();
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _value = _copyWith(isPlaying: false);
    _notify();
  }

  @override
  Future<void> play() async {
    _value = _copyWith(isPlaying: true);
    _notify();
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> seekTo(Duration position) async {
    _value = _copyWith(position: position);
    _notify();
  }

  void complete() {
    _value = _copyWith(isPlaying: false, position: _value.duration);
    _notify();
  }

  VideoPlaybackSnapshot _copyWith({bool? isPlaying, Duration? position}) {
    return VideoPlaybackSnapshot(
      isInitialized: _value.isInitialized,
      isPlaying: isPlaying ?? _value.isPlaying,
      position: position ?? _value.position,
      duration: _value.duration,
      aspectRatio: _value.aspectRatio,
      hasError: _value.hasError,
      errorDescription: _value.errorDescription,
    );
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}

Widget _buildPlayer(
  _FakeVideoController controller, {
  String? cardId = 'video-1',
}) {
  return ProviderScope(
    overrides: [
      videoPlaybackControllerFactoryProvider.overrideWithValue(
        (_) => controller,
      ),
      stopAudioBeforeVideoProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp(
      home: VideoPlaybackScreen(
        checkFileExists: false,
        request: VideoPlaybackRequest(
          path: '/tmp/video.mp4',
          title: 'Space story',
          cardId: cardId,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('autoplays from zero and publishes shared playback state', (
    tester,
  ) async {
    final controller = _FakeVideoController();
    late ProviderContainer container;
    final widget = UncontrolledProviderScope(
      container: container = ProviderContainer(
        overrides: [
          videoPlaybackControllerFactoryProvider.overrideWithValue(
            (_) => controller,
          ),
          stopAudioBeforeVideoProvider.overrideWithValue(() async {}),
        ],
      ),
      child: const MaterialApp(
        home: VideoPlaybackScreen(
          checkFileExists: false,
          request: VideoPlaybackRequest(
            path: '/tmp/video.mp4',
            title: 'Space story',
            cardId: 'video-1',
          ),
        ),
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(widget);
    await tester.pump();

    expect(find.byKey(const ValueKey('fake-video-view')), findsOneWidget);
    expect(controller.value.isPlaying, isTrue);
    expect(controller.value.position, Duration.zero);
    expect(container.read(currentPlayingCardIdProvider), 'video-1');
    expect(container.read(isPlayingProvider), isTrue);
  });

  testWidgets('pauses, replays after completion, and disposes cleanly', (
    tester,
  ) async {
    final controller = _FakeVideoController();
    await tester.pumpWidget(_buildPlayer(controller));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Pause video'));
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);

    controller.complete();
    await tester.pump();
    expect(find.bySemanticsLabel('Replay video'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Replay video'));
    await tester.pump();
    expect(controller.value.position, Duration.zero);
    expect(controller.value.isPlaying, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.disposed, isTrue);
  });

  testWidgets('pauses when the app leaves the foreground', (tester) async {
    final controller = _FakeVideoController();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(_buildPlayer(controller));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.pauseCount, 1);
    expect(controller.value.isPlaying, isFalse);
  });

  testWidgets('hides transport controls after three seconds of playback', (
    tester,
  ) async {
    final controller = _FakeVideoController();
    await tester.pumpWidget(_buildPlayer(controller));
    await tester.pump();

    AnimatedOpacity opacity = tester.widget(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));

    opacity = tester.widget(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0);
    expect(find.bySemanticsLabel('Close video'), findsOneWidget);
  });

  testWidgets('shows an actionable error when initialization fails', (
    tester,
  ) async {
    final controller = _FakeVideoController(initializeError: Exception());
    await tester.pumpWidget(_buildPlayer(controller, cardId: null));
    await tester.pump();

    expect(find.text('Video unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
