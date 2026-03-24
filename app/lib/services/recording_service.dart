import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

enum RecordingState { idle, recording, paused, preview }

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  RecordingState _state = RecordingState.idle;
  String? _recordedFilePath;
  Duration _elapsed = Duration.zero;
  final List<double> amplitudeSamples = [];

  Timer? _durationTimer;
  Timer? _amplitudeTimer;

  final _stateController = StreamController<RecordingState>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  RecordingState get state => _state;
  String? get recordedFilePath => _recordedFilePath;
  Duration get elapsed => _elapsed;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> start() async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${const Uuid().v4()}.m4a';
    _recordedFilePath = '${tempDir.path}/$fileName';

    amplitudeSamples.clear();
    _elapsed = Duration.zero;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
      path: _recordedFilePath!,
    );

    _state = RecordingState.recording;
    _stateController.add(_state);
    _durationController.add(_elapsed);

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      _durationController.add(_elapsed);
    });

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        amplitudeSamples.add(normalized);
        _amplitudeController.add(normalized);
      } catch (_) {}
    });
  }

  Future<void> pause() async {
    await _recorder.pause();
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _state = RecordingState.paused;
    _stateController.add(_state);
  }

  Future<void> resume() async {
    await _recorder.resume();
    _state = RecordingState.recording;
    _stateController.add(_state);

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      _durationController.add(_elapsed);
    });

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amp = await _recorder.getAmplitude();
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        amplitudeSamples.add(normalized);
        _amplitudeController.add(normalized);
      } catch (_) {}
    });
  }

  Future<String?> stop() async {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    final path = await _recorder.stop();
    _state = RecordingState.preview;
    _stateController.add(_state);
    return path ?? _recordedFilePath;
  }

  Future<void> discard() async {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();

    if (await _recorder.isRecording() || await _recorder.isPaused()) {
      await _recorder.stop();
    }

    if (_recordedFilePath != null) {
      try {
        final file = File(_recordedFilePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    _recordedFilePath = null;
    _elapsed = Duration.zero;
    amplitudeSamples.clear();
    _state = RecordingState.idle;
    _stateController.add(_state);
    _durationController.add(_elapsed);
  }

  void dispose() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _stateController.close();
    _durationController.close();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
