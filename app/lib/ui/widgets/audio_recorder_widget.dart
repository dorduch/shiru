import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../../models/audio_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/recording_provider.dart';
import '../../services/audio_service.dart';
import '../../services/library_import_service.dart';
import '../../services/recording_service.dart';
import '../../theme/lantern_tokens.dart';

typedef AudioFilePicker = Future<FilePickerResult?> Function();
typedef MediaSelectionImporter =
    Future<MediaSelection> Function(
      String path,
      CardMediaType mediaType,
      Duration? duration,
    );

class AudioRecorderWidget extends ConsumerStatefulWidget {
  final MediaSelection? currentSelection;
  final ValueChanged<MediaSelection?> onMediaSelected;
  final VoidCallback? onPreviewVideo;
  final Future<XFile?> Function(ImageSource source)? pickVideo;
  final Future<LostDataResponse> Function()? retrieveLostData;
  final AudioFilePicker? pickAudio;
  final MediaSelectionImporter? importMedia;
  final Future<void> Function()? startAudioRecording;
  final Future<void> Function()? restoreSystemUi;

  const AudioRecorderWidget({
    super.key,
    this.currentSelection,
    required this.onMediaSelected,
    this.onPreviewVideo,
    this.pickVideo,
    this.retrieveLostData,
    this.pickAudio,
    this.importMedia,
    this.startAudioRecording,
    this.restoreSystemUi,
  });

  @override
  ConsumerState<AudioRecorderWidget> createState() =>
      _AudioRecorderWidgetState();
}

class _MediaActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  const _MediaActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final foreground = emphasized ? tokens.lantern : tokens.moonDim;
    return Semantics(
      button: true,
      label: '${emphasized ? 'Record' : 'Load'} $label',
      child: SizedBox(
        height: 56,
        child: Material(
          color: emphasized
              ? tokens.lantern.withValues(alpha: 0.16)
              : tokens.nightCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: emphasized ? tokens.lantern : tokens.hush,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioRecorderWidgetState extends ConsumerState<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  RecordingState _recState = RecordingState.idle;
  Duration _elapsed = Duration.zero;
  bool _isPreviewPlaying = false;
  bool _isPickerOpen = false;

  late final AnimationController _pulseController;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _amplitudeSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostVideo());
  }

  Future<XFile?> _pickVideoWithImagePicker(ImageSource source) {
    if (widget.pickVideo != null) return widget.pickVideo!(source);
    return ImagePicker().pickVideo(
      source: source,
      maxDuration: LibraryImportService.maxVideoDuration,
    );
  }

  Future<void> _recoverLostVideo() async {
    try {
      final response = widget.retrieveLostData != null
          ? await widget.retrieveLostData!()
          : await ImagePicker().retrieveLostData();
      if (response.isEmpty) return;
      if (response.exception != null) {
        _showError('Couldn\'t recover the selected video. Please try again.');
        return;
      }
      if (response.type == RetrieveType.image) return;
      final file =
          response.file ??
          ((response.files?.isNotEmpty ?? false)
              ? response.files!.first
              : null);
      if (file != null) await _acceptMedia(file.path, CardMediaType.video);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to recover video picker data: $e');
    }
  }

  void _subscribeToRecording() {
    final service = ref.read(recordingServiceProvider);
    _stateSub?.cancel();
    _durationSub?.cancel();
    _amplitudeSub?.cancel();

    _stateSub = service.stateStream.listen((state) {
      if (mounted) setState(() => _recState = state);
    });
    _durationSub = service.durationStream.listen((d) {
      if (mounted) setState(() => _elapsed = d);
    });
    _amplitudeSub = service.amplitudeStream.listen((amp) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    if (_isPickerOpen) return;
    _isPickerOpen = true;
    if (mounted) setState(() {});

    try {
      final result = await preserveParentAuthDuringExternalFileFlow(
        ref,
        widget.pickAudio ??
            () => FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: LibraryImportService.supportedAudioExtensions,
            ),
      );
      if (result != null && result.files.single.path != null) {
        await _acceptMedia(
          result.files.single.path!,
          CardMediaType.audio,
          sizeBytes: result.files.single.size,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[_AudioRecorderWidgetState] Caught error in _pickAudio: $e',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t open that file. Please try again.'),
          ),
        );
      }
    } finally {
      await _restoreImmersiveMode();
      _isPickerOpen = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickOrRecordVideo(ImageSource source) async {
    if (_isPickerOpen) return;
    _isPickerOpen = true;
    if (mounted) setState(() {});

    try {
      final file = await preserveParentAuthDuringExternalFileFlow(
        ref,
        () => _pickVideoWithImagePicker(source),
      );
      if (file != null) await _acceptMedia(file.path, CardMediaType.video);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to select video: $e');
      _showError(
        source == ImageSource.camera
            ? 'Couldn\'t record that video. Check camera access and try again.'
            : 'Couldn\'t open that video. Please try again.',
      );
    } finally {
      await _restoreImmersiveMode();
      _isPickerOpen = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _acceptMedia(
    String sourcePath,
    CardMediaType mediaType, {
    int? sizeBytes,
    Duration? duration,
  }) async {
    try {
      final resolvedSize = sizeBytes ?? File(sourcePath).lengthSync();
      final validationError = LibraryImportService.validateMediaSelection(
        sourcePath: sourcePath,
        sizeBytes: resolvedSize,
        mediaType: mediaType,
        duration: duration,
      );
      if (validationError != null) {
        _showError(validationError);
        return;
      }
      final selection = widget.importMedia != null
          ? await widget.importMedia!(sourcePath, mediaType, duration)
          : await LibraryImportService.importMediaToLibrary(
              sourcePath,
              mediaType: mediaType,
              duration: duration,
            );
      if (mounted) {
        widget.onMediaSelected(selection);
      } else if (selection.path != sourcePath) {
        await LibraryImportService.deleteImportedMedia(selection.path);
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _restoreImmersiveMode() async {
    try {
      if (widget.restoreSystemUi != null) {
        await widget.restoreSystemUi!();
        return;
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startRecording() async {
    final service = ref.read(recordingServiceProvider);

    if (!await service.hasPermission()) {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone access is needed to record.'),
            ),
          );
        }
        return;
      }
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Microphone Permission'),
              content: const Text(
                'Storytime needs microphone access to record. You can turn it on in Settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    _subscribeToRecording();
    await service.start();
  }

  Future<void> _beginAudioRecording() {
    return widget.startAudioRecording?.call() ?? _startRecording();
  }

  Future<void> _pauseRecording() async {
    await ref.read(recordingServiceProvider).pause();
  }

  Future<void> _resumeRecording() async {
    await ref.read(recordingServiceProvider).resume();
  }

  Future<void> _stopRecording() async {
    final filePath = await ref.read(recordingServiceProvider).stop();
    if (filePath != null) {
      await _acceptMedia(filePath, CardMediaType.audio, duration: _elapsed);
    }
  }

  Future<void> _cancelRecording() async {
    await ref.read(recordingServiceProvider).discard();
    setState(() {
      _recState = RecordingState.idle;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _reRecord() async {
    _stopPreview();
    await ref.read(recordingServiceProvider).discard();
    setState(() {
      _isPreviewPlaying = false;
      _elapsed = Duration.zero;
    });
    await _startRecording();
  }

  void _togglePreview() async {
    final player = ref.read(audioPlayerProvider);
    final service = ref.read(recordingServiceProvider);

    if (_isPreviewPlaying) {
      await player.pause();
      setState(() => _isPreviewPlaying = false);
    } else {
      // Stop any ongoing card playback
      await ref.read(audioServiceProvider).stop();

      final filePath = service.recordedFilePath;
      if (filePath != null) {
        await player.setFilePath(filePath);
        _playerStateSub?.cancel();
        _playerStateSub = player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPreviewPlaying = false);
          }
        });
        await player.play();
        setState(() => _isPreviewPlaying = true);
      }
    }
  }

  void _stopPreview() {
    final player = ref.read(audioPlayerProvider);
    player.stop();
    _playerStateSub?.cancel();
    _isPreviewPlaying = false;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_recState == RecordingState.idle && widget.currentSelection != null) {
      return _buildHasMedia();
    }

    switch (_recState) {
      case RecordingState.idle:
        return _buildSourceSelection();
      case RecordingState.recording:
      case RecordingState.paused:
        return _buildRecording();
      case RecordingState.preview:
        return _buildPreview();
    }
  }

  bool get _isCompactLandscape =>
      MediaQuery.sizeOf(context).height < 500 &&
      MediaQuery.of(context).orientation == Orientation.landscape;

  Widget _buildHasMedia() {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final compactLandscape = _isCompactLandscape;
    final selection = widget.currentSelection!;
    final isVideo = selection.mediaType == CardMediaType.video;

    return Container(
      padding: EdgeInsets.all(compactLandscape ? 12 : 16),
      decoration: BoxDecoration(
        color: tokens.nightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.hueMeadow),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.video_file_outlined : Icons.audio_file,
            color: tokens.hueMeadow,
            size: compactLandscape ? 24 : 28,
          ),
          SizedBox(width: compactLandscape ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(selection),
                  style: TextStyle(
                    fontSize: compactLandscape ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.moon,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isVideo)
                  FutureBuilder<int>(
                    future: File(selection.path).length(),
                    builder: (context, snapshot) {
                      final details = <String>['Video'];
                      if (selection.duration != null) {
                        details.add(_formatDuration(selection.duration!));
                      }
                      if (snapshot.hasData) {
                        details.add(_formatFileSize(snapshot.data!));
                      }
                      return Text(
                        details.join('  •  '),
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.moonDim,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (isVideo && widget.onPreviewVideo != null)
            IconButton(
              tooltip: 'Preview video',
              onPressed: widget.onPreviewVideo,
              icon: Icon(Icons.play_circle_outline, color: tokens.moonDim),
            ),
          SizedBox(width: compactLandscape ? 6 : 8),
          TextButton(
            onPressed: () {
              setState(() => _recState = RecordingState.idle);
              widget.onMediaSelected(null);
            },
            child: Text(
              'Change',
              style: TextStyle(
                color: tokens.lantern,
                fontSize: compactLandscape ? 13 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return megabytes < 10
        ? '${megabytes.toStringAsFixed(1)} MB'
        : '${megabytes.round()} MB';
  }

  String _displayName(MediaSelection selection) {
    final sourceName = selection.sourceName?.trim();
    if (sourceName != null && sourceName.isNotEmpty) return sourceName;

    final fileName = path.basename(selection.path);
    final stem = path.basenameWithoutExtension(fileName);
    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(stem);
    if (isUuid) {
      return selection.mediaType == CardMediaType.video
          ? 'Saved video'
          : 'Saved audio';
    }
    return fileName;
  }

  Widget _buildSourceSelection() {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final compactLandscape = _isCompactLandscape;

    return AbsorbPointer(
      absorbing: _isPickerOpen,
      child: Opacity(
        opacity: _isPickerOpen ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Load from device',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.moon,
              ),
            ),
            SizedBox(height: compactLandscape ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: _MediaActionButton(
                    label: 'Audio',
                    icon: Icons.audio_file_outlined,
                    onPressed: _pickAudio,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaActionButton(
                    label: 'Video',
                    icon: Icons.video_file_outlined,
                    onPressed: () => _pickOrRecordVideo(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            SizedBox(height: compactLandscape ? 10 : 14),
            Text(
              'Record now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.moon,
              ),
            ),
            SizedBox(height: compactLandscape ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: _MediaActionButton(
                    label: 'Audio',
                    icon: Icons.mic_outlined,
                    onPressed: _beginAudioRecording,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaActionButton(
                    label: 'Video',
                    icon: Icons.videocam_outlined,
                    onPressed: () => _pickOrRecordVideo(ImageSource.camera),
                    emphasized: true,
                  ),
                ),
              ],
            ),
            if (_isPickerOpen) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecording() {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final isPaused = _recState == RecordingState.paused;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.nightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.hueCoral, width: 2),
      ),
      child: Column(
        children: [
          // Header: dot + label + timer
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isPaused
                        ? tokens.lantern
                        : Color.lerp(
                            tokens.hueCoral,
                            tokens.hueCoral.withValues(alpha: 0.4),
                            _pulseController.value,
                          ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isPaused ? 'Paused' : 'Recording',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isPaused ? tokens.lantern : tokens.hueCoral,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(_elapsed),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: tokens.moon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waveform
          SizedBox(height: 60, child: _buildWaveform(tokens.hueCoral)),
          const SizedBox(height: 16),
          // Controls
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isPaused ? _resumeRecording : _pauseRecording,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.hush,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          color: tokens.moon,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPaused ? 'Resume' : 'Pause',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.moon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.hueCoral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop, color: tokens.nightDeep, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Stop',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.nightDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _cancelRecording,
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 13, color: tokens.moonFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final service = ref.read(recordingServiceProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.nightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.hueMeadow, width: 2),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: tokens.hueMeadow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recorded',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.hueMeadow,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(service.elapsed),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: tokens.moon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Static waveform
          SizedBox(
            height: 60,
            child: _buildStaticWaveform(
              service.amplitudeSamples,
              tokens.hueMeadow,
            ),
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.hueMeadow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                          color: tokens.nightDeep,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPreviewPlaying ? 'Pause' : 'Play',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.nightDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _reRecord,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: tokens.hush,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: tokens.moon, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Re-record',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.moon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(Color color) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = 4.0;
        final gap = 3.0;
        final barCount = (constraints.maxWidth / (barWidth + gap)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final samples = ref.read(recordingServiceProvider).amplitudeSamples;
            double height;
            if (i < samples.length) {
              // Show real amplitude data
              final sampleIndex = (samples.length - barCount + i).clamp(
                0,
                samples.length - 1,
              );
              height = (samples[sampleIndex] * constraints.maxHeight).clamp(
                4.0,
                constraints.maxHeight,
              );
            } else {
              // Placeholder bars
              height = 4.0;
            }

            return Padding(
              padding: EdgeInsets.only(right: i < barCount - 1 ? gap : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: i < (samples.isNotEmpty ? barCount : 0)
                      ? color
                      : tokens.hush,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStaticWaveform(List<double> samples, Color color) {
    if (samples.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = 4.0;
        final gap = 3.0;
        final barCount = (constraints.maxWidth / (barWidth + gap)).floor();

        // Downsample to fit available bars
        final step = samples.length / barCount;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final sampleIndex = (i * step).floor().clamp(0, samples.length - 1);
            final height = (samples[sampleIndex] * constraints.maxHeight).clamp(
              4.0,
              constraints.maxHeight,
            );

            return Padding(
              padding: EdgeInsets.only(right: i < barCount - 1 ? gap : 0),
              child: Container(
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
