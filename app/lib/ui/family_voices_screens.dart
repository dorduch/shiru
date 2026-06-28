import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/family_voice.dart';
import '../providers/storytime_providers.dart';
import '../services/recording_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'widgets/storytime/storytime.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _statusColor(FamilyVoiceStatus status, StorytimeTokens tokens) =>
    switch (status) {
      FamilyVoiceStatus.ready => const Color(0xFF4CAF50),
      FamilyVoiceStatus.failed => AppColors.destructive,
      _ => tokens.gold,
    };

String _statusLabel(FamilyVoiceStatus status) => switch (status) {
  FamilyVoiceStatus.ready => 'Ready',
  FamilyVoiceStatus.failed => 'Failed',
  FamilyVoiceStatus.cloning => 'Cloning…',
  FamilyVoiceStatus.queued => 'Queued',
  FamilyVoiceStatus.consented => 'Uploading',
  FamilyVoiceStatus.unknown => 'Processing',
};

// ─── s20 · Family Voices List ────────────────────────────────────────────────

class FamilyVoicesScreen extends ConsumerWidget {
  const FamilyVoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final voicesAsync = ref.watch(familyVoicesProvider);

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        title: const Text('Family voices'),
        backgroundColor: tokens.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
      ),
      body: voicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StErrorView(
          icon: Icons.mic_off_rounded,
          title: "Couldn't load voices",
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(familyVoicesProvider),
        ),
        data: (voices) => voices.isEmpty
            ? _EmptyVoices(tokens: tokens)
            : _VoicesList(voices: voices, tokens: tokens),
      ),
      // The empty state has its own primary "Add a voice" button, so only show
      // the FAB once there are voices in the list (avoids two identical CTAs).
      floatingActionButton: voicesAsync.valueOrNull?.isEmpty ?? false
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/parent/family-voices/consent'),
              backgroundColor: tokens.ember,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add a voice'),
            ),
    );
  }
}

class _EmptyVoices extends StatelessWidget {
  const _EmptyVoices({required this.tokens});
  final StorytimeTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_external_on_rounded, size: 64, color: tokens.ember),
        const SizedBox(height: 20),
        StSectionHeader(
          title: 'Add a familiar voice',
          sub: 'Record a family member or upload a clip — their voice can narrate stories for your child.',
          centerAlign: true,
        ),
        const SizedBox(height: 24),
        StButton(
          label: 'Add a voice',
          fullWidth: true,
          onTap: () => context.push('/parent/family-voices/consent'),
        ),
      ],
    ),
  );
}

class _VoicesList extends ConsumerWidget {
  const _VoicesList({required this.voices, required this.tokens});
  final List<FamilyVoice> voices;
  final StorytimeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    itemCount: voices.length,
    separatorBuilder: (context, index) => const SizedBox(height: 8),
    itemBuilder: (context, i) {
      final voice = voices[i];
      return _VoiceRow(voice: voice, tokens: tokens);
    },
  );
}

class _VoiceRow extends ConsumerWidget {
  const _VoiceRow({required this.voice, required this.tokens});
  final FamilyVoice voice;
  final StorytimeTokens tokens;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove voice?'),
        content: Text(
          'This will delete ${voice.name}\'s voice clone and it will no longer be available for stories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref.read(voiceRepositoryProvider).deleteVoice(voice.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not remove voice. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: tokens.paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tokens.line, width: 1),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.ember.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_rounded, color: tokens.ember, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                voice.name,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 15,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                voice.relationship,
                style: AppTypography.labelMedium.copyWith(color: tokens.ink2),
              ),
            ],
          ),
        ),
        StChip(
          label: _statusLabel(voice.status),
          color: _statusColor(voice.status, tokens).withValues(alpha: 0.15),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: tokens.ink3, size: 20),
          tooltip: 'Remove voice',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ],
    ),
  );
}

// ─── s21 · Consent ───────────────────────────────────────────────────────────

class VoiceConsentScreen extends ConsumerStatefulWidget {
  const VoiceConsentScreen({super.key});

  @override
  ConsumerState<VoiceConsentScreen> createState() => _VoiceConsentScreenState();
}

class _VoiceConsentScreenState extends ConsumerState<VoiceConsentScreen> {
  final _nameCtrl = TextEditingController();
  final _relCtrl = TextEditingController();
  bool _agreed = false;
  bool _personIsLiving = true;
  bool _busy = false;
  String? _error;

  bool get _canContinue =>
      _nameCtrl.text.trim().isNotEmpty &&
      _relCtrl.text.trim().isNotEmpty &&
      _agreed &&
      !_busy;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final voiceId = await ref
          .read(voiceRepositoryProvider)
          .createConsent(
            name: _nameCtrl.text.trim(),
            relationship: _relCtrl.text.trim(),
            subjectLiving: _personIsLiving,
          );
      if (mounted) {
        context.push(
          '/parent/family-voices/capture-intro',
          extra: {'voiceId': voiceId, 'name': _nameCtrl.text.trim()},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        title: const Text('Add a voice'),
        backgroundColor: tokens.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StSectionHeader(
              eyebrow: 'Step 1 of 2',
              title: 'Whose voice is this?',
              sub: 'Tell us about the person whose voice will be cloned.',
            ),
            const SizedBox(height: 24),
            StTextField(
              controller: _nameCtrl,
              label: 'Name',
              hint: 'e.g. Grandma Rose',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            StTextField(
              controller: _relCtrl,
              label: 'Relationship to child',
              hint: 'e.g. Grandmother, Dad, Uncle',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            // Living toggle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.line, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Is this person living?',
                          style: AppTypography.bodyLarge.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Some voices are created to preserve memories.',
                          style: AppTypography.bodySmall.copyWith(
                            color: tokens.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _personIsLiving,
                    onChanged: (v) => setState(() => _personIsLiving = v),
                    activeThumbColor: tokens.ember,
                    activeTrackColor: tokens.ember.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Agreement
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _agreed
                      ? tokens.ember.withValues(alpha: 0.08)
                      : tokens.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _agreed ? tokens.ember : tokens.line,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: tokens.ember,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'The person named above agrees to share their voice for story narration in this app.',
                          style: AppTypography.bodySmall.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            StHint(
              text: 'Voice samples are only used to personalise stories for your family and are never shared with others.',
              icon: Icons.lock_outline_rounded,
            ),
          ],
        ),
      ),
      // Pin the error + primary action in a safe-area bottom bar so they can
      // never scroll below the fold (and the CTA clears the home indicator).
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: AppColors.destructiveDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.destructiveDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            StButton(
              label: _busy ? 'Setting up…' : 'Continue',
              fullWidth: true,
              onTap: _canContinue ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── s23 · Capture Intro ─────────────────────────────────────────────────────

class VoiceCaptureIntroScreen extends StatelessWidget {
  const VoiceCaptureIntroScreen({
    super.key,
    required this.voiceId,
    required this.name,
  });

  final String voiceId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        title: const Text('Add a voice'),
        backgroundColor: tokens.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.mic_external_on_rounded, size: 64, color: tokens.ember),
              const SizedBox(height: 20),
              StSectionHeader(
                eyebrow: 'Step 2 of 2',
                title: 'Capture $name\'s voice',
                sub: 'We need a short recording to create the voice clone. Choose how you\'d like to add it.',
                centerAlign: true,
              ),
              const SizedBox(height: 32),
              // Option A — guided capture
              _CaptureOption(
                icon: Icons.record_voice_over_rounded,
                title: 'Record now',
                subtitle: 'Read 5 short prompts aloud — takes about 2 minutes.',
                onTap: () => context.push(
                  '/parent/family-voices/capture',
                  extra: {'voiceId': voiceId, 'name': name},
                ),
              ),
              const SizedBox(height: 12),
              // Option B — upload
              _CaptureOption(
                icon: Icons.upload_file_rounded,
                title: 'Upload a clip',
                subtitle: 'Pick an audio file of ~1 minute or longer.',
                onTap: () => context.push(
                  '/parent/family-voices/upload',
                  extra: {'voiceId': voiceId, 'name': name},
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureOption extends StatelessWidget {
  const _CaptureOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.line, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tokens.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tokens.ember, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 15,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.ink3),
          ],
        ),
      ),
    );
  }
}

// ─── s24 · Guided Capture ────────────────────────────────────────────────────

const List<_Prompt> _capturePrompts = [
  _Prompt(
    label: 'Warm & friendly',
    text:
        'Once upon a time, in a cosy little cottage at the edge of a friendly forest, there lived a curious rabbit who loved to collect shiny pebbles.',
  ),
  _Prompt(
    label: 'Calm & slow',
    text:
        'The stars began to appear one by one, like tiny lanterns being lit across a velvet sky, and the world grew quiet and still.',
  ),
  _Prompt(
    label: 'Excited & bright',
    text:
        '"We found it!" she cried, jumping up and down. "The golden feather is right here, hidden inside the old oak tree — just like the map said!"',
  ),
  _Prompt(
    label: 'Gentle & soft',
    text:
        'He tucked the little bear snugly under the blanket, whispered goodnight to the moon peeking through the curtain, and smiled.',
  ),
  _Prompt(
    label: 'Curious & wondering',
    text:
        'What could be inside? She pressed her ear to the shell and heard — very faintly — the sound of waves, and laughter, and something magical.',
  ),
];

class _Prompt {
  const _Prompt({required this.label, required this.text});
  final String label;
  final String text;
}

class GuidedCaptureScreen extends ConsumerStatefulWidget {
  const GuidedCaptureScreen({
    super.key,
    required this.voiceId,
    required this.name,
  });

  final String voiceId;
  final String name;

  @override
  ConsumerState<GuidedCaptureScreen> createState() =>
      _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends ConsumerState<GuidedCaptureScreen> {
  final RecordingService _recorder = RecordingService();
  int _promptIndex = 0;
  final List<String> _recordedPaths = [];
  bool _recording = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      // Stop
      final path = await _recorder.stop();
      if (path != null) {
        _recordedPaths.add(path);
      }
      setState(() => _recording = false);

      if (_promptIndex < _capturePrompts.length - 1) {
        setState(() => _promptIndex++);
      } else {
        // All done — upload
        await _submitSamples();
      }
    } else {
      // Check permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Microphone permission is needed to record voice samples.',
                ),
              ),
            );
          }
          return;
        }
      }
      await _recorder.start();
      setState(() => _recording = true);
    }
  }

  Future<void> _submitSamples() async {
    setState(() => _uploading = true);
    try {
      final authUser = await ref.read(authUserProvider.future);
      if (authUser == null) throw Exception('Not signed in');
      await ref
          .read(voiceRepositoryProvider)
          .uploadSamplesAndClone(
            uid: authUser.uid,
            voiceId: widget.voiceId,
            localFilePaths: _recordedPaths,
          );
      if (mounted) {
        context.pushReplacement(
          '/parent/family-voices/ready',
          extra: {'voiceId': widget.voiceId, 'name': widget.name},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final prompt = _capturePrompts[_promptIndex];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (_recording) await _recorder.stop();
      },
      child: Scaffold(
        backgroundColor: tokens.night1,
        appBar: AppBar(
          title: Text('${widget.name}\'s voice'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: tokens.cream,
        ),
        body: SafeArea(
          child: _uploading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        'Uploading samples…',
                        style: AppTypography.bodyLarge.copyWith(
                          color: tokens.cream,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: StDots(
                          totalSteps: _capturePrompts.length,
                          activeStep: _promptIndex,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '${_promptIndex + 1} of ${_capturePrompts.length}',
                          style: AppTypography.labelMedium.copyWith(
                            color: tokens.cream.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      StChip(
                        label: prompt.label,
                        color: tokens.ember.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      StPrompt(promptText: prompt.text),
                      const Spacer(),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.destructive,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Center(
                        child: StVoiceWave(active: _recording),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: StRecordButton(
                          isRecording: _recording,
                          onTap: _toggleRecord,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _recording ? 'Tap to stop' : 'Tap to record',
                          style: AppTypography.labelMedium.copyWith(
                            color: tokens.cream.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        StButton(
                          label: 'Retry upload',
                          fullWidth: true,
                          onTap: _submitSamples,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── s21u · Upload a clip ────────────────────────────────────────────────────

class VoiceUploadScreen extends ConsumerStatefulWidget {
  const VoiceUploadScreen({
    super.key,
    required this.voiceId,
    required this.name,
  });

  final String voiceId;
  final String name;

  @override
  ConsumerState<VoiceUploadScreen> createState() => _VoiceUploadScreenState();
}

class _VoiceUploadScreenState extends ConsumerState<VoiceUploadScreen> {
  String? _pickedPath;
  String? _pickedName;
  bool _uploading = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPath = result.files.single.path;
        _pickedName = result.files.single.name;
        _error = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_pickedPath == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final authUser = await ref.read(authUserProvider.future);
      if (authUser == null) throw Exception('Not signed in');
      await ref
          .read(voiceRepositoryProvider)
          .uploadSamplesAndClone(
            uid: authUser.uid,
            voiceId: widget.voiceId,
            localFilePaths: [_pickedPath!],
          );
      if (mounted) {
        context.pushReplacement(
          '/parent/family-voices/ready',
          extra: {'voiceId': widget.voiceId, 'name': widget.name},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        title: const Text('Upload a clip'),
        backgroundColor: tokens.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StSectionHeader(
                title: 'Upload ${widget.name}\'s voice',
                sub: 'Pick an audio clip of about one minute or longer. Clear speech works best.',
              ),
              const SizedBox(height: 24),
              StHint(
                text: 'A quiet room, natural speech, and at least 60 seconds gives the best result.',
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _uploading ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedPath != null ? tokens.ember : tokens.line,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pickedPath != null
                            ? Icons.audio_file_rounded
                            : Icons.upload_file_rounded,
                        size: 48,
                        color: _pickedPath != null ? tokens.ember : tokens.ink3,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _pickedPath != null
                            ? (_pickedName ?? 'File selected')
                            : 'Tap to pick an audio file',
                        style: AppTypography.bodyLarge.copyWith(
                          color: _pickedPath != null ? tokens.ink : tokens.ink3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.destructive,
                  ),
                ),
              ],
              const Spacer(),
              StButton(
                label: _uploading ? 'Uploading…' : 'Upload & create voice',
                fullWidth: true,
                onTap: (_pickedPath != null && !_uploading) ? _upload : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── s22 · Voice Ready / Status ──────────────────────────────────────────────

class VoiceReadyScreen extends ConsumerWidget {
  const VoiceReadyScreen({
    super.key,
    required this.voiceId,
    required this.name,
  });

  final String voiceId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final voicesAsync = ref.watch(familyVoicesProvider);

    final voice = voicesAsync.valueOrNull?.firstWhere(
      (v) => v.id == voiceId,
      orElse: () => FamilyVoice(
        id: voiceId,
        name: name,
        relationship: '',
        subjectLiving: true,
        status: FamilyVoiceStatus.queued,
        createdAt: DateTime.now(),
      ),
    );

    final status = voice?.status ?? FamilyVoiceStatus.queued;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        title: const Text('Voice status'),
        backgroundColor: tokens.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: _StatusIcon(status: status, tokens: tokens),
              ),
              const SizedBox(height: 24),
              StSectionHeader(
                title: _titleFor(status, name),
                sub: _subtitleFor(status),
                centerAlign: true,
              ),
              const SizedBox(height: 32),
              if (status.isProcessing) ...[
                Center(
                  child: LinearProgressIndicator(
                    backgroundColor: tokens.line,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.ember),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'This can take a few minutes…',
                    style: AppTypography.labelMedium.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (status == FamilyVoiceStatus.ready)
                StButton(
                  label: 'Use in a story',
                  fullWidth: true,
                  onTap: () {
                    // Pre-select this family voice and navigate to the wizard.
                    ref
                        .read(storyDraftProvider.notifier)
                        .setFamilyVoice(voiceId);
                    context.go('/make/character');
                  },
                )
              else if (status == FamilyVoiceStatus.failed)
                StButton(
                  label: 'Go back',
                  variant: StButtonVariant.ghost,
                  fullWidth: true,
                  onTap: () => context.go('/parent/family-voices'),
                )
              else
                StButton(
                  label: 'Done',
                  variant: StButtonVariant.ghost,
                  fullWidth: true,
                  onTap: () => context.go('/parent/family-voices'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(FamilyVoiceStatus status, String n) => switch (status) {
    FamilyVoiceStatus.ready => '$n\'s voice is ready!',
    FamilyVoiceStatus.failed => 'Something went wrong',
    _ => 'Creating $n\'s voice…',
  };

  String _subtitleFor(FamilyVoiceStatus status) => switch (status) {
    FamilyVoiceStatus.ready =>
      'You can now choose this voice when making a story.',
    FamilyVoiceStatus.failed =>
      'We couldn\'t create this voice clone. Please go back and try again.',
    _ =>
      'We\'re turning the recording into a voice clone. You\'ll be able to use it in stories shortly.',
  };
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.tokens});
  final FamilyVoiceStatus status;
  final StorytimeTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (status == FamilyVoiceStatus.ready) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 56,
        ),
      );
    }
    if (status == FamilyVoiceStatus.failed) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error_outline_rounded,
          color: AppColors.destructive,
          size: 56,
        ),
      );
    }
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: tokens.ember.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.mic_rounded, color: tokens.ember, size: 56),
    );
  }
}
