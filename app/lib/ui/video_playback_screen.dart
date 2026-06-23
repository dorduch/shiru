import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../models/audio_card.dart';
import '../providers/audio_player_provider.dart';
import '../providers/cards_provider.dart';
import '../services/audio_service.dart';

class VideoPlaybackRequest {
  const VideoPlaybackRequest({
    required this.path,
    required this.title,
    this.cardId,
  });

  final String path;
  final String title;
  final String? cardId;
}

class VideoPlaybackSnapshot {
  const VideoPlaybackSnapshot({
    required this.isInitialized,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.aspectRatio,
    required this.hasError,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final bool hasError;
  final String? errorDescription;

  bool get isCompleted =>
      isInitialized &&
      duration > Duration.zero &&
      position >= duration - const Duration(milliseconds: 250);
}

abstract class VideoPlaybackController {
  VideoPlaybackSnapshot get value;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Widget buildView();
  Future<void> dispose();
}

typedef VideoPlaybackControllerFactory =
    VideoPlaybackController Function(String path);

final videoPlaybackControllerFactoryProvider =
    Provider<VideoPlaybackControllerFactory>((ref) {
      return (path) => PlatformVideoPlaybackController(path);
    });

final stopAudioBeforeVideoProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(audioServiceProvider).stop();
});

class PlatformVideoPlaybackController implements VideoPlaybackController {
  PlatformVideoPlaybackController(String path)
    : _controller = VideoPlayerController.file(File(path));

  final VideoPlayerController _controller;

  @override
  VideoPlaybackSnapshot get value {
    final value = _controller.value;
    return VideoPlaybackSnapshot(
      isInitialized: value.isInitialized,
      isPlaying: value.isPlaying,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
      hasError: value.hasError,
      errorDescription: value.errorDescription,
    );
  }

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> play() => _controller.play();

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);
}

class VideoPlaybackScreen extends ConsumerStatefulWidget {
  const VideoPlaybackScreen({
    super.key,
    required this.request,
    this.checkFileExists = true,
  });

  final VideoPlaybackRequest request;
  final bool checkFileExists;

  @override
  ConsumerState<VideoPlaybackScreen> createState() =>
      _VideoPlaybackScreenState();
}

class VideoCardPlaybackScreen extends ConsumerWidget {
  const VideoCardPlaybackScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    return cards.when(
      data: (cards) {
        AudioCard? card;
        for (final candidate in cards) {
          if (candidate.id == cardId) {
            card = candidate;
            break;
          }
        }

        if (card == null || card.mediaType != CardMediaType.video) {
          return _UnavailableVideoRoute(onClose: () => _leaveRoute(context));
        }

        return VideoPlaybackScreen(
          key: ValueKey(card.id),
          request: VideoPlaybackRequest(
            path: card.mediaPath,
            title: card.title,
            cardId: card.id,
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF07090D),
        body: _VideoLoadingState(),
      ),
      error: (_, _) =>
          _UnavailableVideoRoute(onClose: () => _leaveRoute(context)),
    );
  }
}

class _UnavailableVideoRoute extends StatelessWidget {
  const _UnavailableVideoRoute({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: _VideoErrorState(
        message: 'This video is no longer in the library.',
        onRetry: onClose,
        onClose: onClose,
      ),
    );
  }
}

class _VideoPlaybackScreenState extends ConsumerState<VideoPlaybackScreen>
    with WidgetsBindingObserver {
  late final StateController<String?> _currentPlayingCardId;
  late final StateController<bool> _isPlaying;
  VideoPlaybackController? _controller;
  Timer? _hideControlsTimer;
  bool _initializing = true;
  bool _controlsVisible = true;
  bool _wasPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPlayingCardId = ref.read(currentPlayingCardIdProvider.notifier);
    _isPlaying = ref.read(isPlayingProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    _hideControlsTimer?.cancel();
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_handleControllerChange);
      await previous.dispose();
    }

    if (mounted) {
      setState(() {
        _controller = null;
        _initializing = true;
        _controlsVisible = true;
        _errorMessage = null;
        _wasPlaying = false;
      });
    }

    try {
      await ref.read(stopAudioBeforeVideoProvider)();
      if (!mounted) return;
      _setSharedPlayback(isPlaying: false);

      if (widget.checkFileExists && !await File(widget.request.path).exists()) {
        throw const _VideoPlaybackFailure(
          'This video file is missing. Ask a parent to choose it again.',
        );
      }

      final controller = ref.read(videoPlaybackControllerFactoryProvider)(
        widget.request.path,
      );
      _controller = controller;
      controller.addListener(_handleControllerChange);
      await controller.initialize();
      if (!mounted || controller != _controller) return;
      if (controller.value.hasError) {
        throw _VideoPlaybackFailure(_friendlyPlaybackError());
      }
      await controller.seekTo(Duration.zero);
      await controller.play();
      if (!mounted || controller != _controller) return;
      setState(() => _initializing = false);
      _setSharedPlayback(isPlaying: true);
      _scheduleControlsHide();
    } on _VideoPlaybackFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(_friendlyPlaybackError());
    }
  }

  String _friendlyPlaybackError() {
    return "This video can't play on this device. Try an MP4, MOV, or M4V file with a supported codec.";
  }

  void _showError(String message) {
    if (!mounted) return;
    _setSharedPlayback(isPlaying: false);
    setState(() {
      _initializing = false;
      _controlsVisible = true;
      _errorMessage = message;
    });
  }

  void _setSharedPlayback({required bool isPlaying}) {
    final cardId = widget.request.cardId;
    if (cardId == null) return;
    _currentPlayingCardId.state = cardId;
    _isPlaying.state = isPlaying;
  }

  void _handleControllerChange() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    if (value.hasError && _errorMessage == null) {
      _showError(_friendlyPlaybackError());
      return;
    }

    final startedPlaying = value.isPlaying && !_wasPlaying;
    final stoppedPlaying = !value.isPlaying && _wasPlaying;
    _wasPlaying = value.isPlaying;
    _setSharedPlayback(isPlaying: value.isPlaying);

    if (startedPlaying) {
      _scheduleControlsHide();
    } else if (stoppedPlaying || value.isCompleted) {
      _hideControlsTimer?.cancel();
      _controlsVisible = true;
    }

    setState(() {});
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _revealControls() {
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isCompleted) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seekTo(double milliseconds) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration(milliseconds: milliseconds.round()));
    _revealControls();
  }

  void _close() {
    _leaveRoute(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller?.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    final controller = _controller;
    controller?.removeListener(_handleControllerChange);
    if (controller != null) unawaited(controller.dispose());

    final cardId = widget.request.cardId;
    if (cardId != null && _currentPlayingCardId.state == cardId) {
      _currentPlayingCardId.state = null;
      _isPlaying.state = false;
    }
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: Semantics(
        label: 'Video player for ${widget.request.title}',
        container: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (value?.isInitialized ?? false)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _revealControls,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: value!.aspectRatio,
                    child: controller!.buildView(),
                  ),
                ),
              ),
            if (_initializing)
              const _VideoLoadingState()
            else if (_errorMessage != null)
              _VideoErrorState(
                message: _errorMessage!,
                onRetry: _initialize,
                onClose: _close,
              )
            else if (value != null && value.isInitialized)
              _TransportControls(
                visible: _controlsVisible || !value.isPlaying,
                title: widget.request.title,
                value: value,
                onTogglePlayback: _togglePlayback,
                onSeek: _seekTo,
                onInteraction: _revealControls,
              ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _PlayerIconButton(
                    semanticLabel: 'Close video',
                    icon: Icons.close_rounded,
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.visible,
    required this.title,
    required this.value,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onInteraction,
  });

  final bool visible;
  final String title;
  final VideoPlaybackSnapshot value;
  final VoidCallback onTogglePlayback;
  final ValueChanged<double> onSeek;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final durationMs = value.duration.inMilliseconds.toDouble();
    final positionMs = value.position.inMilliseconds
        .clamp(0, value.duration.inMilliseconds)
        .toDouble();
    final isCompleted = value.isCompleted;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuart,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2207090D),
                    Color(0x0007090D),
                    Color(0xCC07090D),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
            Center(
              child: Semantics(
                button: true,
                label: isCompleted
                    ? 'Replay video'
                    : value.isPlaying
                    ? 'Pause video'
                    : 'Play video',
                child: Material(
                  color: const Color(0xD9F8FAFC),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTogglePlayback,
                    child: SizedBox.square(
                      dimension: 88,
                      child: Icon(
                        isCompleted
                            ? Icons.replay_rounded
                            : value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 50,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _formatDuration(value.position),
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: durationMs > 0 ? positionMs : 0,
                              min: 0,
                              max: durationMs > 0 ? durationMs : 1,
                              activeColor: const Color(0xFFFF6B6B),
                              inactiveColor: const Color(0x66F8FAFC),
                              onChangeStart: (_) => onInteraction(),
                              onChanged: durationMs > 0 ? onSeek : null,
                            ),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _VideoLoadingState extends StatelessWidget {
  const _VideoLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading video',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFF8FAFC)),
            SizedBox(height: 16),
            Text(
              'Opening video…',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_file_outlined,
                color: Color(0xFFFFB4B4),
                size: 56,
              ),
              const SizedBox(height: 18),
              const Text(
                'Video unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 17,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFF64748B)),
                      minimumSize: const Size(112, 52),
                    ),
                    child: const Text('Close'),
                  ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size(112, 52),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: const Color(0xCC111827),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 56,
            child: Icon(icon, color: const Color(0xFFF8FAFC), size: 30),
          ),
        ),
      ),
    );
  }
}

class _VideoPlaybackFailure implements Exception {
  const _VideoPlaybackFailure(this.message);

  final String message;
}

void _leaveRoute(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
