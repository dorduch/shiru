import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../../providers/audio_player_provider.dart';
import '../../providers/recording_provider.dart';
import '../../services/audio_service.dart';
import '../../services/recording_service.dart';

class AudioRecorderWidget extends ConsumerStatefulWidget {
  final String? currentAudioPath;
  final ValueChanged<String> onAudioSelected;

  const AudioRecorderWidget({
    Key? key,
    this.currentAudioPath,
    required this.onAudioSelected,
  }) : super(key: key);

  @override
  ConsumerState<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends ConsumerState<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  RecordingState _recState = RecordingState.idle;
  Duration _elapsed = Duration.zero;
  bool _isPreviewPlaying = false;

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
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      const maxBytes = 200 * 1024 * 1024; // 200 MB
      final fileSize = result.files.single.size;
      if (fileSize > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is too large. Maximum size is 200 MB.')),
          );
        }
        return;
      }
      widget.onAudioSelected(result.files.single.path!);
    }
  }

  Future<void> _startRecording() async {
    final service = ref.read(recordingServiceProvider);

    if (!await service.hasPermission()) {
      final status = await Permission.microphone.request();
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required for recording.')),
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
              content: const Text('Enable microphone access in settings to record.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  Future<void> _pauseRecording() async {
    await ref.read(recordingServiceProvider).pause();
  }

  Future<void> _resumeRecording() async {
    await ref.read(recordingServiceProvider).resume();
  }

  Future<void> _stopRecording() async {
    final filePath = await ref.read(recordingServiceProvider).stop();
    if (filePath != null) {
      widget.onAudioSelected(filePath);
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
    // If we have audio and we're idle, show the current audio info
    if (_recState == RecordingState.idle && widget.currentAudioPath != null) {
      return _buildHasAudio();
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

  Widget _buildHasAudio() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file, color: Color(0xFF22C55E), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path.basename(widget.currentAudioPath!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() => _recState = RecordingState.idle);
              widget.onAudioSelected(''); // Clear to show source selection
            },
            child: const Text('Change', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickAudio,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, color: Color(0xFF6B7280), size: 32),
                  SizedBox(height: 8),
                  Text('Choose File', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  SizedBox(height: 4),
                  Text('Import Audio', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _startRecording,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text('Record', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Use Microphone', style: TextStyle(fontSize: 12, color: Color(0xFFFECACA))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    final isPaused = _recState == RecordingState.paused;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444), width: 2),
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
                        ? const Color(0xFFFCD34D)
                        : Color.lerp(const Color(0xFFEF4444), const Color(0x66EF4444), _pulseController.value),
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
                  color: isPaused ? const Color(0xFFFCD34D) : const Color(0xFFEF4444),
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waveform
          SizedBox(
            height: 60,
            child: _buildWaveform(const Color(0xFFEF4444)),
          ),
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
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isPaused ? 'Resume' : 'Pause',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Stop', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
            child: const Text('Cancel', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final service = ref.read(recordingServiceProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E), width: 2),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              const Text('Recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
              const Spacer(),
              Text(
                _formatDuration(service.elapsed),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Static waveform
          SizedBox(
            height: 60,
            child: _buildStaticWaveform(service.amplitudeSamples, const Color(0xFF22C55E)),
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
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isPreviewPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isPreviewPlaying ? 'Pause' : 'Play',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
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
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Re-record', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
              final sampleIndex = (samples.length - barCount + i).clamp(0, samples.length - 1);
              height = (samples[sampleIndex] * constraints.maxHeight).clamp(4.0, constraints.maxHeight);
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
                  color: i < (samples.isNotEmpty ? barCount : 0) ? color : const Color(0xFF4B5563),
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
            final height = (samples[sampleIndex] * constraints.maxHeight).clamp(4.0, constraints.maxHeight);

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
