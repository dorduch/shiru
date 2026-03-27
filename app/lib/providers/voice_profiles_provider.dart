import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_profile.dart';
import '../models/story_builder_state.dart';
import '../db/database_service.dart';
import '../services/voice_clone_service.dart';

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

  Future<void> addProfile(String name, String audioFilePath, TtsProvider provider) async {
    final voiceId = await VoiceCloneService.cloneVoice(
      name: name,
      audioFilePath: audioFilePath,
      provider: provider,
    );
    final profile = VoiceProfile(
      id: const Uuid().v4(),
      name: name,
      voiceId: voiceId,
      samplePath: audioFilePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      provider: provider == TtsProvider.elevenlabs ? 'elevenlabs' : 'cartesia',
    );
    await DatabaseService.instance.createVoiceProfile(profile);
    await loadProfiles();
  }

  Future<void> deleteProfile(String id) async {
    final profiles = state.value ?? [];
    final profile = profiles.firstWhere((p) => p.id == id);
    final ttsProvider = profile.provider == 'elevenlabs'
        ? TtsProvider.elevenlabs
        : TtsProvider.cartesia;
    await VoiceCloneService.deleteVoice(profile.voiceId, provider: ttsProvider);
    await DatabaseService.instance.deleteVoiceProfile(id);
    await loadProfiles();
  }
}

final voiceProfilesProvider = StateNotifierProvider<VoiceProfilesNotifier, AsyncValue<List<VoiceProfile>>>((ref) {
  return VoiceProfilesNotifier();
});
