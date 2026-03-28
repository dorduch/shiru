import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_profile.dart';
import '../db/database_service.dart';

class VoiceProfilesNotifier extends StateNotifier<AsyncValue<List<VoiceProfile>>> {
  VoiceProfilesNotifier() : super(const AsyncValue.loading()) {
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    try {
      final profiles = await DatabaseService.instance.readAllVoiceProfiles();
      state = AsyncValue.data(profiles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addProfile(String name, String audioFilePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = audioFilePath.split('.').last;
    final destPath = '${dir.path}/voice_${const Uuid().v4()}.$ext';
    await File(audioFilePath).copy(destPath);
    final profile = VoiceProfile(
      id: const Uuid().v4(),
      name: name,
      samplePath: destPath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.createVoiceProfile(profile);
    await loadProfiles();
  }

  Future<void> deleteProfile(String id) async {
    final profiles = state.value ?? [];
    final profile = profiles.firstWhere((p) => p.id == id);
    try { await File(profile.samplePath).delete(); } catch (_) {}
    await DatabaseService.instance.deleteVoiceProfile(id);
    await loadProfiles();
  }
}

final voiceProfilesProvider = StateNotifierProvider<VoiceProfilesNotifier, AsyncValue<List<VoiceProfile>>>((ref) {
  return VoiceProfilesNotifier();
});
