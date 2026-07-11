import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../models/family_voice.dart';
import '../providers/storytime_providers.dart';
import '../services/recording_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'widgets/lantern/lantern.dart';
import 'widgets/storytime/storytime.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _statusColor(LanternTokens tokens, FamilyVoiceStatus status) =>
    switch (status) {
      // Centralized per the Lantern spec §3: this hardcoded green was never
      // a token to begin with — now LanternTokens.hueMeadow.
      FamilyVoiceStatus.ready => tokens.hueMeadow,
      FamilyVoiceStatus.failed => tokens.hueCoral,
      _ => tokens.lantern,
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final voicesAsync = ref.watch(familyVoicesProvider);

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Family voices'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: voicesAsync.when(
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
      ),
      // The empty state has its own primary "Add a voice" button, so only show
      // the FAB once there are voices in the list (avoids two identical CTAs).
      floatingActionButton: voicesAsync.valueOrNull?.isEmpty ?? false
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/parent/family-voices/consent'),
              backgroundColor: tokens.lantern,
              // nightDeep for AA contrast on the light lantern fill — same
              // convention GlowButton uses for its ctaGradient label/icon.
              foregroundColor: tokens.nightDeep,
              icon: const Icon(Icons.add),
              label: const Text('Add a voice'),
            ),
    );
  }
}

class _EmptyVoices extends StatelessWidget {
  const _EmptyVoices({required this.tokens});
  final LanternTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_external_on_rounded, size: 64, color: tokens.lantern),
        const SizedBox(height: 20),
        LanternSectionHeader(
          title: 'Add a familiar voice',
          sub: 'Record a family member or upload a clip — their voice can narrate stories for your child.',
          centerAlign: true,
        ),
        const SizedBox(height: 24),
        GlowButton(
          label: 'Add a voice',
          onTap: () => context.push('/parent/family-voices/consent'),
        ),
      ],
    ),
  );
}

class _VoicesList extends ConsumerWidget {
  const _VoicesList({required this.voices, required this.tokens});
  final List<FamilyVoice> voices;
  final LanternTokens tokens;

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
  final LanternTokens tokens;

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
      color: tokens.nightCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tokens.hush, width: 1),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.lantern.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_rounded, color: tokens.lantern, size: 22),
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
                  color: tokens.moon,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                voice.relationship,
                style: AppTypography.labelMedium.copyWith(color: tokens.moonDim),
              ),
            ],
          ),
        ),
        LanternChip(
          label: _statusLabel(voice.status),
          hue: _statusColor(tokens, voice.status),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: tokens.moonFaint, size: 20),
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Add a voice'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LanternSectionHeader(
                eyebrow: 'Step 1 of 2',
                title: 'Whose voice is this?',
                sub: 'Tell us about the person whose voice will be cloned.',
              ),
              const SizedBox(height: 24),
              LanternTextField(
                controller: _nameCtrl,
                label: 'Name',
                hint: 'e.g. Grandma Rose',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              LanternTextField(
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
                  color: tokens.nightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.hush, width: 1),
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
                              color: tokens.moon,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Some voices are created to preserve memories.',
                            style: AppTypography.bodySmall.copyWith(
                              color: tokens.moonDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _personIsLiving,
                      onChanged: (v) => setState(() => _personIsLiving = v),
                      activeThumbColor: tokens.lantern,
                      activeTrackColor: tokens.lantern.withValues(alpha: 0.5),
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
                        ? tokens.lantern.withValues(alpha: 0.08)
                        : tokens.nightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _agreed ? tokens.lantern : tokens.hush,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        activeColor: tokens.lantern,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'The person named above agrees to share their voice for story narration in this app.',
                            style: AppTypography.bodySmall.copyWith(
                              color: tokens.moon,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // StHint has no Lantern equivalent yet and this is its only
              // call site in this file — inlined re-skin per the rollout
              // spec's guidance on low-usage components (see StToggle note),
              // matching VoiceUploadScreen's own StHint inline re-skin.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.nightCard,
                  borderRadius: AppRadius.medium,
                  border: Border.all(color: tokens.hush, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: tokens.lantern, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Voice samples are only used to personalise stories for your family and are never shared with others.',
                        style: AppTypography.labelMedium.copyWith(color: tokens.moonDim),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  Icon(Icons.error_outline_rounded,
                      size: 18, color: tokens.hueCoral),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTypography.bodySmall.copyWith(
                        color: tokens.hueCoral,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            GlowButton(
              label: _busy ? 'Setting up…' : 'Continue',
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Add a voice'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.mic_external_on_rounded, size: 64, color: tokens.lantern),
                const SizedBox(height: 20),
                LanternSectionHeader(
                  eyebrow: 'Step 2 of 2',
                  title: 'Capture $name\'s voice',
                  sub: 'We need a short recording to create the voice clone. Choose how you\'d like to add it.',
                  centerAlign: true,
                ),
                const SizedBox(height: 32),
                // Option A — guided capture
                LanternRow(
                  leading: _VoiceCaptureGlyph(
                    icon: Icons.record_voice_over_rounded,
                    tokens: tokens,
                  ),
                  title: 'Record now',
                  subtitle: 'Read 5 short prompts aloud — takes about 2 minutes.',
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: tokens.moonFaint),
                  onTap: () => context.push(
                    '/parent/family-voices/capture',
                    extra: {'voiceId': voiceId, 'name': name},
                  ),
                ),
                const SizedBox(height: 12),
                // Option B — upload
                LanternRow(
                  leading: _VoiceCaptureGlyph(
                    icon: Icons.upload_file_rounded,
                    tokens: tokens,
                  ),
                  title: 'Upload a clip',
                  subtitle: 'Pick an audio file of ~1 minute or longer.',
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: tokens.moonFaint),
                  onTap: () => context.push(
                    '/parent/family-voices/upload',
                    extra: {'voiceId': voiceId, 'name': name},
                  ),
                ),
                const SizedBox(height: 12),
                // Option C — invite someone else to record
                LanternRow(
                  leading: _VoiceCaptureGlyph(
                    icon: Icons.ios_share_rounded,
                    tokens: tokens,
                  ),
                  title: 'Invite someone to record',
                  subtitle: 'Send a link — they record in any browser.',
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: tokens.moonFaint),
                  onTap: () => context.push(
                    '/parent/family-voices/invite',
                    extra: {'voiceId': voiceId, 'name': name},
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon glyph used as [LanternRow.leading] for this screen's
/// two capture-method rows — same shape as `_DashboardGlyph` in
/// `lib/ui/storytime_screens.dart` (private to that file, so mirrored here
/// rather than shared).
class _VoiceCaptureGlyph extends StatelessWidget {
  const _VoiceCaptureGlyph({required this.icon, required this.tokens});
  final IconData icon;
  final LanternTokens tokens;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 24,
    backgroundColor: tokens.lantern.withValues(alpha: 0.12),
    child: Icon(icon, color: tokens.lantern, size: 22),
  );
}

// ─── s23i · Invite Share ─────────────────────────────────────────────────────

/// Third capture option offered from [VoiceCaptureIntroScreen]: generates a
/// one-time link so someone else can record the voice samples themselves in
/// any browser, then lets the parent copy/share that link.
class VoiceInviteShareScreen extends ConsumerStatefulWidget {
  const VoiceInviteShareScreen({
    super.key,
    required this.voiceId,
    required this.name,
  });

  final String voiceId;
  final String name;

  @override
  ConsumerState<VoiceInviteShareScreen> createState() =>
      _VoiceInviteShareScreenState();
}

class _VoiceInviteShareScreenState extends ConsumerState<VoiceInviteShareScreen> {
  bool _loading = true;
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createInvite();
  }

  Future<void> _createInvite() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite =
          await ref.read(voiceRepositoryProvider).createInvite(widget.voiceId);
      if (mounted) {
        setState(() {
          _url = invite.url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't create the invite link. Please try again.";
        });
      }
    }
  }

  Future<void> _copyLink() async {
    final url = _url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied.')),
      );
    }
  }

  void _shareLink() {
    final url = _url;
    if (url == null) return;
    Share.share(url);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Invite to record'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: tokens.lantern),
                      const SizedBox(height: 20),
                      Text(
                        'Creating your invite link…',
                        style: AppTypography.bodyLarge.copyWith(color: tokens.moon),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? StErrorView(
                      icon: Icons.link_off_rounded,
                      title: "Couldn't create invite",
                      message: _error,
                      onRetry: _createInvite,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Icon(Icons.ios_share_rounded, size: 64, color: tokens.lantern),
                          const SizedBox(height: 20),
                          LanternSectionHeader(
                            title: 'Invite ${widget.name}\'s voice',
                            sub: 'Send this link to the person whose voice you want to '
                                'record. It works in any browser — no app needed. The '
                                'link expires in 7 days.',
                            centerAlign: true,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tokens.nightCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: tokens.hush, width: 1),
                            ),
                            child: Text(
                              _url ?? '',
                              style: AppTypography.labelMedium.copyWith(color: tokens.moonDim),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GlowButton(
                            label: 'Copy link',
                            leading: const Icon(Icons.copy_rounded),
                            onTap: _copyLink,
                          ),
                          const SizedBox(height: 12),
                          LanternOutlineButton(
                            label: 'Share',
                            leading: const Icon(Icons.ios_share_rounded),
                            onTap: _shareLink,
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final prompt = _capturePrompts[_promptIndex];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (_recording) await _recorder.stop();
      },
      child: Scaffold(
        backgroundColor: tokens.nightMid,
        appBar: AppBar(
          title: Text('${widget.name}\'s voice'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: tokens.moon,
        ),
        body: Container(
          decoration: BoxDecoration(gradient: tokens.nightGradient),
          child: SafeArea(
            child: _uploading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: tokens.lantern),
                        const SizedBox(height: 20),
                        Text(
                          'Uploading samples…',
                          style: AppTypography.bodyLarge.copyWith(
                            color: tokens.moon,
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
                              color: tokens.moonDim,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        LanternChip(
                          label: prompt.label,
                          hue: tokens.lantern,
                        ),
                        const SizedBox(height: 16),
                        StPrompt(promptText: prompt.text),
                        const Spacer(),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: AppTypography.bodySmall.copyWith(
                              color: tokens.hueCoral,
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
                              color: tokens.moonDim,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          GlowButton(
                            label: 'Retry upload',
                            onTap: _submitSamples,
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Upload a clip'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LanternSectionHeader(
                  title: 'Upload ${widget.name}\'s voice',
                  sub: 'Pick an audio clip of about one minute or longer. Clear speech works best.',
                ),
                const SizedBox(height: 24),
                // StHint has no Lantern equivalent yet and this is its only
                // call site in this file — inlined re-skin per the rollout
                // spec's guidance on low-usage components (see StToggle note).
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: tokens.nightCard,
                    borderRadius: AppRadius.medium,
                    border: Border.all(color: tokens.hush, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: tokens.lantern, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'A quiet room, natural speech, and at least 60 seconds gives the best result.',
                          style: AppTypography.labelMedium.copyWith(color: tokens.moonDim),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _uploading ? null : _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: tokens.nightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _pickedPath != null ? tokens.lantern : tokens.hush,
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
                          color: _pickedPath != null ? tokens.lantern : tokens.moonFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pickedPath != null
                              ? (_pickedName ?? 'File selected')
                              : 'Tap to pick an audio file',
                          style: AppTypography.bodyLarge.copyWith(
                            color: _pickedPath != null ? tokens.moon : tokens.moonFaint,
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
                      color: tokens.hueCoral,
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
    final tokens = Theme.of(context).extension<LanternTokens>()!;
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
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        title: const Text('Voice status'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
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
                LanternSectionHeader(
                  title: _titleFor(status, name),
                  sub: _subtitleFor(status),
                  centerAlign: true,
                ),
                const SizedBox(height: 32),
                if (status.isProcessing) ...[
                  Center(
                    child: LinearProgressIndicator(
                      backgroundColor: tokens.hush,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.lantern),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'This can take a few minutes…',
                      style: AppTypography.labelMedium.copyWith(
                        color: tokens.moonFaint,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (status == FamilyVoiceStatus.ready)
                  GlowButton(
                    label: 'Use in a story',
                    onTap: () {
                      // Pre-select this family voice and start a fresh story
                      // draft, then jump straight into the Composer — mirrors
                      // StorytimeHomeScreen's "Make a Story" tile / the
                      // StoryEndScreen "Make another" button's reset +
                      // shuffleAll sequence, with setFamilyVoice layered on
                      // top since this screen's whole purpose is picking the
                      // narrator. `/make/character` was the old per-slot
                      // wizard's first step; the router now redirects it
                      // straight to `/compose`, so go there directly.
                      ref.read(storyDraftProvider.notifier).reset();
                      ref.read(storyDraftProvider.notifier).shuffleAll();
                      ref
                          .read(storyDraftProvider.notifier)
                          .setFamilyVoice(voiceId);
                      context.go('/compose');
                    },
                  )
                else if (status == FamilyVoiceStatus.failed)
                  LanternOutlineButton(
                    label: 'Go back',
                    onTap: () => context.go('/parent/family-voices'),
                  )
                else
                  LanternOutlineButton(
                    label: 'Done',
                    onTap: () => context.go('/parent/family-voices'),
                  ),
              ],
            ),
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
  final LanternTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (status == FamilyVoiceStatus.ready) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          // Centralized per the Lantern spec §3: this hardcoded green used to
          // be a bespoke literal, never a token — now LanternTokens.hueMeadow.
          color: tokens.hueMeadow.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle_rounded,
          color: tokens.hueMeadow,
          size: 56,
        ),
      );
    }
    if (status == FamilyVoiceStatus.failed) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: tokens.hueCoral.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error_outline_rounded,
          color: tokens.hueCoral,
          size: 56,
        ),
      );
    }
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: tokens.lantern.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.mic_rounded, color: tokens.lantern, size: 56),
    );
  }
}
