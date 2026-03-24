import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recording_service.dart';

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});
