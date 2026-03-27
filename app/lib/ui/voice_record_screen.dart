import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../models/story_builder_state.dart';
import '../providers/voice_profiles_provider.dart';
import '../providers/audio_player_provider.dart';
import '../services/recording_service.dart';
import 'widgets/story_option_card.dart';

enum _Step { providerSelection, nameInput, recording, preview, processing, done, error }

const _guidedScript =
    'Hello! My name is [your name] and I love telling stories. '
    'Once upon a time, in a land far away, there lived a brave little rabbit '
    'who wanted to explore the world. Every morning, the rabbit would hop out '
    'of its cozy burrow and greet the sunshine with a cheerful smile.';

class VoiceRecordScreen extends ConsumerStatefulWidget {
  const VoiceRecordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends ConsumerState<VoiceRecordScreen> {
  _Step _step = _Step.providerSelection;
  final _nameController = TextEditingController();
  final _recordingService = RecordingService();

  String? _recordedPath;
  TtsProvider? _selectedProvider;
  Duration _elapsed = Duration.zero;
  double _amplitude = 0;
  String? _errorMessage;
  bool _previewPlaying = false;

  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<double>? _ampSub;

  @override
  void dispose() {
    _nameController.dispose();
    _durationSub?.cancel();
    _ampSub?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    final hasPerm = await _recordingService.hasPermission();
    if (!hasPerm) {
      setState(() {
        _errorMessage = 'Microphone permission denied.';
        _step = _Step.error;
      });
      return;
    }

    await _recordingService.start();

    _durationSub = _recordingService.durationStream.listen((d) {
      if (mounted) setState(() => _elapsed = d);
    });
    _ampSub = _recordingService.amplitudeStream.listen((a) {
      if (mounted) setState(() => _amplitude = a);
    });

    setState(() => _step = _Step.recording);
  }

  Future<void> _stopRecording() async {
    HapticFeedback.mediumImpact();
    _durationSub?.cancel();
    _ampSub?.cancel();
    final path = await _recordingService.stop();
    setState(() {
      _recordedPath = path;
      _step = _Step.preview;
    });
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() {
      _recordedPath = path;
      _step = _Step.preview;
    });
  }

  Future<void> _togglePreview() async {
    HapticFeedback.lightImpact();
    final player = ref.read(audioPlayerProvider);
    if (_previewPlaying) {
      await player.stop();
      setState(() => _previewPlaying = false);
    } else {
      setState(() => _previewPlaying = true);
      try {
        await player.setFilePath(_recordedPath!);
        await player.play();
        player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        ).then((_) {
          if (mounted) setState(() => _previewPlaying = false);
        });
      } catch (_) {
        if (mounted) setState(() => _previewPlaying = false);
      }
    }
  }

  Future<void> _reRecord() async {
    HapticFeedback.lightImpact();
    final player = ref.read(audioPlayerProvider);
    await player.stop();
    await _recordingService.discard();
    _durationSub?.cancel();
    _ampSub?.cancel();
    setState(() {
      _recordedPath = null;
      _elapsed = Duration.zero;
      _amplitude = 0;
      _previewPlaying = false;
      _step = _Step.nameInput;
    });
  }

  Future<void> _processVoice() async {
    HapticFeedback.mediumImpact();
    final player = ref.read(audioPlayerProvider);
    await player.stop();
    setState(() => _step = _Step.processing);
    try {
      await ref.read(voiceProfilesProvider.notifier).addProfile(
            _nameController.text.trim(),
            _recordedPath!,
            _selectedProvider!,
          );
      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _step = _Step.error;
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: switch (_step) {
            _Step.providerSelection => _buildProviderSelection(),
            _Step.nameInput => _buildNameInput(),
            _Step.recording => _buildRecording(),
            _Step.preview => _buildPreview(),
            _Step.processing => _buildProcessing(),
            _Step.done => _buildDone(),
            _Step.error => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String title, int activeDot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 28),
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800)),
            const Spacer(),
            _StepDots(active: activeDot, total: 4),
          ],
        ),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Choose Engine', 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: StoryOptionCard(
                  emoji: '🔊',
                  label: 'ElevenLabs',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _selectedProvider = TtsProvider.elevenlabs;
                      _step = _Step.nameInput;
                    });
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: StoryOptionCard(
                  emoji: '🎵',
                  label: 'Cartesia',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _selectedProvider = TtsProvider.cartesia;
                      _step = _Step.nameInput;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Record Voice', 2),
        const SizedBox(height: 24),
        const Text('Voice Name',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g. Grandma Sarah',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        const Text('Read this aloud when recording:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            _guidedScript,
            style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF374151)),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _nameController.text.trim().isNotEmpty ? _startRecording : null,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: _nameController.text.trim().isNotEmpty
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.white),
                SizedBox(width: 8),
                Text('Start Recording',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _uploadFile,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, color: Color(0xFF6B7280)),
                SizedBox(width: 8),
                Text('Upload Recording',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Recording...', 3),
        const Spacer(),
        Center(
          child: Text(
            _formatDuration(_elapsed),
            style: const TextStyle(
                fontSize: 56, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
          ),
        ),
        const SizedBox(height: 32),
        _WaveformBar(amplitude: _amplitude),
        const Spacer(),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40EF4444),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop, color: Colors.white),
                SizedBox(width: 8),
                Text('Stop',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Preview', 3),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: _togglePreview,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _previewPlaying
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _previewPlaying ? Icons.stop : Icons.play_arrow,
                size: 48,
                color: _previewPlaying
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _previewPlaying ? 'Playing...' : 'Tap to preview',
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _reRecord,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, color: Color(0xFF6B7280)),
                SizedBox(width: 8),
                Text('Re-record',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _processVoice,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x408B5CF6),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Use This Voice',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
        SizedBox(height: 24),
        Center(
          child: Text('Cloning your voice...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 8),
        Center(
          child: Text('This may take a moment.',
              style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 80),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('Voice Added!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '"${_nameController.text.trim()}" is ready to use.',
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x4022C55E),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, color: Colors.white),
                SizedBox(width: 8),
                Text('Back to Voices',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 80),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('Something went wrong',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        if (_errorMessage != null)
          Center(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _step = _Step.providerSelection;
              _errorMessage = null;
              _recordedPath = null;
              _elapsed = Duration.zero;
              _selectedProvider = null;
            });
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, color: Colors.white),
                SizedBox(width: 8),
                Text('Try Again',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final int active;
  final int total;

  const _StepDots({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i + 1 == active;
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF8B5CF6)
                : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  final double amplitude;

  const _WaveformBar({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    final barCount = 30;
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (i) {
          final heightFactor = (0.1 + amplitude * (0.5 + 0.5 * ((i % 5) / 5)));
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 80 * heightFactor,
            decoration: BoxDecoration(
              color: Color.fromRGBO(239, 68, 68, 0.7 + 0.3 * amplitude),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
