import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../models/voice_profile.dart';
import '../providers/voice_profiles_provider.dart';
import '../providers/audio_player_provider.dart';

const _avatarColors = [
  Color(0xFFEDE9FE),
  Color(0xFFDCFCE7),
  Color(0xFFFEF9C3),
  Color(0xFFFEE2E2),
];

class VoiceProfilesScreen extends ConsumerWidget {
  const VoiceProfilesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(voiceProfilesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text('Voices',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w800)),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/parent/voices/record');
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: profilesAsync.when(
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return const Center(
                        child: Text(
                          'No voices yet.\nAdd a voice to personalize stories!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _VoiceProfileRow(
                          profile: profiles[index],
                          avatarColor: _avatarColors[index % _avatarColors.length],
                          onDelete: () => _confirmDelete(context, ref, profiles[index]),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text(e.toString())),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/parent/voices/record');
                },
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
                      Icon(Icons.mic, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Voice',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, VoiceProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${profile.name}"?'),
        content: const Text('This voice will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(voiceProfilesProvider.notifier).deleteProfile(profile.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _VoiceProfileRow extends ConsumerStatefulWidget {
  final VoiceProfile profile;
  final Color avatarColor;
  final VoidCallback onDelete;

  const _VoiceProfileRow({
    Key? key,
    required this.profile,
    required this.avatarColor,
    required this.onDelete,
  }) : super(key: key);

  @override
  ConsumerState<_VoiceProfileRow> createState() => _VoiceProfileRowState();
}

class _VoiceProfileRowState extends ConsumerState<_VoiceProfileRow> {
  bool _isPlaying = false;

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleSample() async {
    HapticFeedback.lightImpact();
    final player = ref.read(audioPlayerProvider);

    if (_isPlaying) {
      await player.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      try {
        await player.setFilePath(widget.profile.samplePath);
        await player.play();
        player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        ).then((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      } catch (_) {
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Voice profile: ${widget.profile.name}',
      child: Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.avatarColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              widget.profile.name.isNotEmpty ? widget.profile.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.profile.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Created ${_formatDate(widget.profile.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Semantics(
            label: _isPlaying ? 'Stop sample' : 'Play sample',
            button: true,
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.stop_circle : Icons.play_circle,
                color: const Color(0xFF22C55E),
                size: 32,
              ),
              onPressed: _toggleSample,
            ),
          ),
          Semantics(
            label: 'Delete ${widget.profile.name}',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 24),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    ),
  );
  }
}
