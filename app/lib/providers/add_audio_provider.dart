import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/library_import_service.dart';

/// Holds the captured/imported audio between the capture and details steps.
final addAudioDraftProvider = StateProvider<MediaSelection?>((ref) => null);
