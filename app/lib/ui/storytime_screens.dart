import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../models/storytime_models.dart';
import '../models/story_origin_label.dart';
import '../providers/audio_player_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/storytime_providers.dart';
import '../logic/story_tokenizer.dart';
import '../services/curated_timing_service.dart';
import '../services/library_import_service.dart';
import '../services/starter_story_service.dart';
import '../services/story_generation_repository.dart';
import '../services/analytics_service.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'widgets/storytime/storytime.dart';
import 'widgets/lantern/lantern.dart';
import 'concept_icons.dart';
import 'pixel_sprite.dart';

class StorytimeLaunchScreen extends ConsumerWidget {
  const StorytimeLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    // No more per-screen `Theme(data: StorytimeTheme.bedtime, ...)` wrap here
    // — the root theme (main.dart) already registers LanternTokens.night(),
    // so this screen reads it directly (see
    // docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md §2).
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    Widget content = user.when(
      loading: () => const _NightLoadingScaffold(),
      error: (error, stackTrace) =>
          _LaunchError(onRetry: () => ref.invalidate(authUserProvider)),
      data: (authUser) {
        if (authUser == null) {
          _goAfterBuild(context, '/welcome');
          return const _NightLoadingScaffold();
        }
        final profile = ref.watch(childProfileProvider);
        return profile.when(
          loading: () => const _NightLoadingScaffold(),
          error: (error, stackTrace) =>
              _LaunchError(onRetry: () => ref.invalidate(childProfileProvider)),
          data: (child) {
            if (child == null) {
              _goAfterBuild(context, '/child-setup');
            } else {
              _resumeOrGoHome(context, ref, authUser.uid);
            }
            return const _NightLoadingScaffold();
          },
        );
      },
    );
    return Container(
      color: tokens.nightDeep,
      child: content,
    );
  }

  void _resumeOrGoHome(BuildContext context, WidgetRef ref, String uid) {
    Future.wait([
          ref.read(activeStoryJobServiceProvider).load(uid),
          StarterStoryService().seedIfNeeded(),
        ])
        .then((results) async {
          await ref.read(cardsProvider.notifier).loadCards();
          if (!context.mounted) return;
          final jobId = results.first as String?;
          context.go(jobId == null ? '/home' : '/generate?jobId=$jobId');
        })
        .catchError((Object error) {
          if (context.mounted) context.go('/home');
        });
  }
}

void _goAfterBuild(BuildContext context, String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.go(location);
  });
}

class _NightLoadingScaffold extends StatelessWidget {
  const _NightLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: Center(
        child: CircularProgressIndicator(color: tokens.lantern),
      ),
    );
  }
}

class _LaunchError extends StatelessWidget {
  const _LaunchError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: SafeArea(
        child: StErrorView(
          icon: Icons.nightlight_round,
          title: 'Storytime could not start',
          message: 'Something went wrong getting things ready. Let\'s try again.',
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class StorytimeWelcomeScreen extends StatelessWidget {
  const StorytimeWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        color: tokens.lantern.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(38),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PixelSprite(
                            sprite: autoAssignSprite('storybook'),
                            scale: 7,
                          ),
                          Positioned(
                            right: 20,
                            top: 16,
                            child: Text(
                              '✦',
                              style: TextStyle(
                                fontSize: 34,
                                color: tokens.lantern,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const LanternSectionHeader(
                      title: 'Storytime',
                      sub: 'Magical stories for little listeners.',
                      centerAlign: true,
                    ),
                    const SizedBox(height: 36),
                    GlowButton(
                      label: 'Get started',
                      onTap: () => context.go('/auth?mode=create'),
                    ),
                    const SizedBox(height: 12),
                    LanternOutlineButton(
                      label: 'I already have an account',
                      onTap: () => context.go('/auth?mode=signin'),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'A grown-up creates the account. Child names and listening history stay on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.moonDim, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StorytimeAuthScreen extends ConsumerStatefulWidget {
  const StorytimeAuthScreen({super.key, required this.createMode});
  final bool createMode;

  @override
  ConsumerState<StorytimeAuthScreen> createState() =>
      _StorytimeAuthScreenState();
}

class _StorytimeAuthScreenState extends ConsumerState<StorytimeAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(authUserProvider);
      ref.invalidate(childProfileProvider);
      context.go('/');
    } on FirebaseFunctionsException catch (error) {
      setState(() => _error = error.message ?? 'Could not sign in.');
    } catch (error) {
      setState(() => _error = _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('invalid-credential')) {
      return 'Check your email and password.';
    }
    if (text.contains('email-already-in-use')) {
      return 'That email already has an account.';
    }
    if (text.contains('weak-password')) {
      return 'Use at least 6 characters for the password.';
    }
    if (text.contains('canceled')) return 'Sign-in was canceled.';
    return 'Could not sign in. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.createMode ? 'Create account' : 'Sign in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Grown-ups set up the account. This takes a minute.',
                  ),
                  const SizedBox(height: 24),
                  LanternTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  LanternTextField(
                    controller: _password,
                    label: 'Password',
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: tokens.hueCoral),
                    ),
                  ],
                  const SizedBox(height: 18),
                  GlowButton(
                    label: _busy ? 'Please wait…' : 'Continue',
                    onTap: _busy
                        ? null
                        : () => _run(() {
                            final auth = ref.read(authRepositoryProvider);
                            return widget.createMode
                                ? auth.createWithEmail(
                                    _email.text,
                                    _password.text,
                                  )
                                : auth.signInWithEmail(
                                    _email.text,
                                    _password.text,
                                  );
                          }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  LanternOutlineButton(
                    label: 'Continue with Apple',
                    leading: const Icon(Icons.apple),
                    onTap: _busy
                        ? null
                        : () => _run(
                            ref.read(authRepositoryProvider).signInWithApple),
                  ),
                  const SizedBox(height: 10),
                  LanternOutlineButton(
                    label: 'Continue with Google',
                    leading: const Icon(Icons.account_circle_outlined),
                    onTap: _busy
                        ? null
                        : () => _run(
                            ref.read(authRepositoryProvider).signInWithGoogle),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "By continuing, the grown-up agrees that Storytime may send story choices and an age band to our generation providers. We never send the child's name.",
                    style: TextStyle(color: tokens.moonDim, height: 1.45),
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

class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key, this.returnLocation = '/home'});
  final String returnLocation;

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  final _name = TextEditingController();
  AgeBand _ageBand = AgeBand.early;
  String _avatar = 'Sunny fox';
  bool _busy = false;
  String? _error;

  static const avatars = ['Sunny fox', 'Brave bear', 'Magic unicorn'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(childProfileServiceProvider)
          .save(
            user.uid,
            ChildProfile(
              name: _name.text.trim(),
              ageBand: _ageBand,
              avatarSpriteKey: autoAssignSprite(_avatar).id,
            ),
          );
      await StarterStoryService().seedIfNeeded();
      await ref.read(cardsProvider.notifier).loadCards();
      ref.invalidate(childProfileProvider);
      if (mounted) context.go(widget.returnLocation);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not finish setup. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Add your child')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Age sets the story length. The profile stays encrypted on this device.',
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: avatars
                        .map(
                          (avatar) => LanternChoiceCard(
                            label: avatar,
                            selected: _avatar == avatar,
                            onTap: () => setState(() => _avatar = avatar),
                            glyph: PixelSprite(
                              sprite: autoAssignSprite(avatar),
                              scale: 4.5,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  LanternTextField(
                    controller: _name,
                    label: 'First name',
                  ),
                  const SizedBox(height: 20),
                  LanternSegment(
                    options: AgeBand.values.map((b) => b.label).toList(),
                    selectedIndex: AgeBand.values.indexOf(_ageBand),
                    onChanged: (i) =>
                        setState(() => _ageBand = AgeBand.values[i]),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: tokens.hueCoral),
                    ),
                  ],
                  const SizedBox(height: 28),
                  GlowButton(
                    label: _busy ? 'Setting up…' : 'Done',
                    onTap: _busy ? null : _save,
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

class StorytimeHomeScreen extends ConsumerWidget {
  const StorytimeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final profile = ref.watch(childProfileProvider).valueOrNull;
    final cards = ref.watch(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final resumable =
        cards.where((card) => card.playbackPosition > 5000).toList()..sort(
          (a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0),
        );
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LanternScreenHeader(
                  title: 'Hi ${profile?.name ?? 'there'}!',
                  sub: 'What should we do today?',
                  largeTitle: true,
                  trailing: TextButton.icon(
                    onPressed: () => context.go('/parent-access?next=/parent'),
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Grown-up'),
                    // Reads as a deliberate control (outlined pill) rather than
                    // a bare text link — adult-discoverable, but de-emphasized
                    // (moonDim/nightCard) so it isn't a target for kids.
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.moonDim,
                      backgroundColor: tokens.nightCard,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: tokens.hush),
                      ),
                    ),
                  ),
                ),
                if (resumable.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ResumeStrip(card: resumable.first),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth > 680;
                      final makeAction = LanternActionTile(
                        title: 'Make a Story',
                        subtitle: 'Build your own adventure',
                        emphasized: true,
                        glyph: SvgPicture.string(
                          storybookIconSvg,
                          width: 104,
                          height: 104,
                        ),
                        onTap: () {
                          ref.read(storyDraftProvider.notifier).reset();
                          ref.read(storyDraftProvider.notifier).shuffleAll();
                          context.go('/compose');
                        },
                      );
                      final listenAction = LanternActionTile(
                        title: 'Listen',
                        subtitle: '${cards.length} stories',
                        emphasized: false,
                        glyph: SvgPicture.string(
                          headphonesIconSvg,
                          width: 92,
                          height: 92,
                        ),
                        onTap: () => context.go('/listen'),
                      );
                      return horizontal
                          ? Row(
                              children: [
                                Expanded(flex: 2, child: makeAction),
                                const SizedBox(width: 16),
                                Expanded(child: listenAction),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: makeAction),
                                const SizedBox(height: 14),
                                Expanded(child: listenAction),
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumeStrip extends StatelessWidget {
  const _ResumeStrip({required this.card});
  final AudioCard card;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return LanternRow(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: tokens.lantern,
        child: Text(
          '▶',
          style: TextStyle(
            color: tokens.nightDeep,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      title: 'Keep going',
      subtitle: card.title,
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.moonFaint, size: 20),
      onTap: () => context.go('/story/${card.id}'),
    );
  }
}

class StoryGeneratingScreen extends ConsumerStatefulWidget {
  const StoryGeneratingScreen({super.key, this.existingJobId});
  final String? existingJobId;

  @override
  ConsumerState<StoryGeneratingScreen> createState() =>
      _StoryGeneratingScreenState();
}

class _StoryGeneratingScreenState extends ConsumerState<StoryGeneratingScreen> {
  StreamSubscription<StoryJob>? _subscription;
  String? _jobId;
  String _status = 'Getting the story ready…';
  String? _error;
  bool _importing = false;
  // Set once the first job snapshot arrives — used as the loading-art
  // concept on the resume path, where the draft may be empty (app relaunched
  // mid-generation) so there's no character/theme choice to read locally yet.
  StoryTheme? _jobTheme;

  @override
  void initState() {
    super.initState();
    _jobId = widget.existingJobId;
    Future.microtask(_start);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final profile = await ref.read(childProfileProvider.future);
    if (user == null || profile == null) {
      if (mounted) context.go('/');
      return;
    }
    try {
      await _subscription?.cancel();
      var jobId = _jobId;
      if (jobId == null) {
        final draft = ref.read(storyDraftProvider);
        final result = await ref
            .read(storyGenerationRepositoryProvider)
            .createJob(
              draft: draft,
              ageBand: profile.ageBand,
              idempotencyKey: const Uuid().v4(),
            );
        jobId = result.jobId;
        _jobId = jobId;
        await ref.read(activeStoryJobServiceProvider).save(user.uid, jobId);
      }
      _subscription = ref
          .read(storyGenerationRepositoryProvider)
          .watchJob(user.uid, jobId)
          .listen(
            _onJob,
            onError: (Object error) {
              if (mounted) {
                setState(
                  () => _error =
                      'We lost the connection. Check the internet and try again.',
                );
              }
            },
          );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.code == 'resource-exhausted'
            ? "That's all of today's stories. More story magic will be ready tomorrow."
            : 'Story making is resting right now. Please try again.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not start the story. Please try again.');
      }
    }
  }

  void _onJob(StoryJob job) {
    if (!mounted) return;
    setState(() {
      _jobTheme = job.theme;
      _status = switch (job.status) {
        StoryJobStatus.queued => 'Gathering a little magic…',
        StoryJobStatus.writing => 'Writing your story…',
        StoryJobStatus.checking => 'Making sure it feels just right…',
        StoryJobStatus.narrating => "Adding the storyteller's voice…",
        StoryJobStatus.ready => 'Saving your story…',
        StoryJobStatus.failed => 'The story magic fizzled this time.',
      };
    });
    if (job.status == StoryJobStatus.failed) {
      _jobId = null;
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid != null) {
        ref.read(activeStoryJobServiceProvider).clear(uid);
      }
      setState(
        () => _error = job.errorCode == 'safety'
            ? 'That story did not pass our safety check. Try a different surprise.'
            : 'The storytellers could not finish. Please try again.',
      );
    } else if (job.status == StoryJobStatus.ready && !_importing) {
      _import(job);
    }
  }

  Future<void> _import(StoryJob job) async {
    _importing = true;
    try {
      final response = await http.get(Uri.parse(job.downloadUrl!));
      if (response.statusCode != 200) throw HttpException('Download failed');
      final temp = await getTemporaryDirectory();
      final tempPath = '${temp.path}/${const Uuid().v4()}.mp3';
      await File(tempPath).writeAsBytes(response.bodyBytes);
      final path = await LibraryImportService.importAudioToLibrary(tempPath);
      final cards = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
      final card = AudioCard(
        id: const Uuid().v4(),
        collectionId: 'default-stories',
        title: job.title!,
        color: job.theme.color,
        spriteKey: job.theme.name,
        audioPath: path,
        storyOrigin: StoryOrigin.generated,
        narratorKey: job.narratorKey,
        position: cards.length,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        storyText: job.story,
        wordStarts: job.wordStarts,
      );
      await ref.read(cardsProvider.notifier).addCard(card);
      await ref.read(storyGenerationRepositoryProvider).confirmImported(job.id);
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(activeStoryJobServiceProvider).clear(uid);
      ref.read(storyDraftProvider.notifier).reset();
      if (mounted) context.go('/story/${card.id}');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The story was made, but it could not be saved. Try again while online.',
        );
      }
      _importing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // No more per-screen `Theme(data: StorytimeTheme.bedtime, ...)` wrap here
    // — the root theme (main.dart) already registers LanternTokens.night(),
    // so this screen reads it directly instead of forcing a redundant
    // sub-theme (see docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md §2).
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    // Loading art follows the story being generated: prefer the chosen
    // character, then the chosen theme (fresh-creation path, from the local
    // draft), then the in-flight job's theme once its first snapshot arrives
    // (resume path, where the draft may be empty). Falls back to a neutral
    // bedtime/moon token before any of those are available so the layout
    // never collapses.
    final draft = ref.watch(storyDraftProvider);
    final Object concept = draft.character ?? draft.theme ?? _jobTheme ?? StoryTheme.bedtime;
    final conceptEmoji = draft.character?.emoji ??
        (draft.theme ?? _jobTheme ?? StoryTheme.bedtime).emoji;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                // Bottom-heavy padding nudges the vertically-centered
                // block up a touch: geometric-center content reads
                // slightly low and the heavy sprite biases mass downward.
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 52),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StConceptToken(
                      value: concept,
                      emoji: conceptEmoji,
                      iconSize: 112,
                      fill: false,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      // Don't keep the loading headline over a failure —
                      // swap to an error title when something went wrong.
                      _error == null ? _status : 'Oh no, a little hiccup',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium.copyWith(color: tokens.moon),
                    ),
                    const SizedBox(height: 20),
                    if (_error == null)
                      LinearProgressIndicator(
                        minHeight: 8,
                        // Lantern accent for the active fill, `hush` for the
                        // dim track — same track/fill idiom as the other
                        // Lantern job-status progress bar (family voice
                        // processing, family_voices_screens.dart).
                        color: tokens.lantern,
                        backgroundColor: tokens.hush,
                      )
                    else ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          // hueCoral: the established Lantern destructive/error
                          // color, used for the same purpose elsewhere in this
                          // file and in family_voices_screens.dart.
                          color: tokens.hueCoral,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GlowButton(
                        label: 'Try again',
                        onTap: () {
                          setState(() => _error = null);
                          _start();
                        },
                      ),
                      const SizedBox(height: 8),
                      LanternOutlineButton(
                        label: 'Back home',
                        onTap: () => context.go('/home'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key, this.parentMode = false});
  final bool parentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final cards = ref.watch(cardsProvider);

    // ── Parent mode: keep the existing AppBar + ListView ─────────────────────
    if (parentMode) {
      return Scaffold(
        backgroundColor: tokens.nightMid,
        appBar: AppBar(
          title: Text(
            'Manage stories',
            style: AppTypography.headlineSmall.copyWith(color: tokens.moon),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: tokens.moon,
          leading: BackButton(
            onPressed: () => context.go('/parent'),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(gradient: tokens.nightGradient),
          child: SafeArea(
            child: cards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: GlowButton(
                  label: 'Try again',
                  onTap: ref.read(cardsProvider.notifier).loadCards,
                ),
              ),
              data: (stories) {
                if (stories.isEmpty) {
                  return Center(
                    child: Text(
                      'No stories yet. Make one from Home.',
                      style: AppTypography.bodySmall
                          .copyWith(color: tokens.moonDim),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: stories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _StoryTile(card: stories[index], parentMode: true),
                );
              },
            ),
          ),
        ),
      );
    }

    // ── Kid mode: rich PixelSprite tile grid ──────────────────────────────────
    final resumable = (cards.valueOrNull ?? const <AudioCard>[])
        .where((c) => c.playbackPosition > 5000)
        .toList()
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));

    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LanternScreenHeader(
                  onBack: () => context.go('/home'),
                  title: 'Listen',
                  sub: '${cards.valueOrNull?.length ?? 0} stories',
                  largeTitle: true,
                ),
                if (resumable.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResumeStrip(card: resumable.first),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: cards.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: GlowButton(
                        label: 'Try again',
                        onTap: ref.read(cardsProvider.notifier).loadCards,
                      ),
                    ),
                    data: (stories) => stories.isEmpty
                        ? Center(
                            child: Text(
                              'No stories yet. Make one from Home.',
                              style: AppTypography.bodySmall
                                  .copyWith(color: tokens.moonDim),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: stories.length,
                            itemBuilder: (context, i) =>
                                _StoryGridTile(card: stories[i]),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryTile extends ConsumerWidget {
  const _StoryTile({required this.card, required this.parentMode});
  final AudioCard card;
  final bool parentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Semantics(
      label: '${card.title}, ${storyOriginSemantics(card.storyOrigin)}',
      button: !parentMode,
      excludeSemantics: true,
      child: LanternRow(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: hexOrFallback(card.color),
          // Show the story's own character (rich SVG for curated stories,
          // pixel sprite otherwise) instead of a blank color dot, so each row
          // has a real visual cue (not color alone).
          child: ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: StoryAvatar(card: card, conceptSize: 32, pixelScale: 2.4),
            ),
          ),
        ),
        title: card.title,
        subtitle: storyOriginSubtitle(card.storyOrigin),
        trailing: parentMode
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                if (card.storyOrigin == StoryOrigin.uploaded)
                  GestureDetector(
                    onTap: () => context.go('/parent/edit-audio/${card.id}'),
                    child: Icon(Icons.edit_outlined, color: tokens.moonFaint, size: 20),
                  ),
                if (card.storyOrigin == StoryOrigin.uploaded)
                  const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _delete(context, ref),
                  child: Icon(Icons.delete_outline, color: tokens.moonFaint, size: 20),
                ),
              ])
            : Icon(Icons.chevron_right_rounded, color: tokens.moonFaint, size: 20),
        onTap: parentMode ? null : () => context.go('/story/${card.id}'),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this story?'),
        content: Text(
          '${card.title} and its audio will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cardsProvider.notifier).deleteCard(card.id);
    }
  }
}

class _StoryGridTile extends StatelessWidget {
  const _StoryGridTile({required this.card});
  final AudioCard card;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Semantics(
      button: true,
      label: '${card.title}, ${storyOriginSemantics(card.storyOrigin)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/story/${card.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.nightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.hush),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hexOrFallback(card.color),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: StoryAvatar(card: card, conceptSize: 72, pixelScale: 3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                  color: tokens.moon,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                storyOriginSubtitle(card.storyOrigin),
                style:
                    AppTypography.labelMedium.copyWith(color: tokens.moonDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryPlayerScreen extends ConsumerStatefulWidget {
  const StoryPlayerScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends ConsumerState<StoryPlayerScreen>
    with WidgetsBindingObserver {
  AudioCard? _card;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  Timer? _saveTimer;
  bool _completed = false;
  bool _loading = true;
  String? _error;
  // Captured in initState so the disposal path (dispose / _savePosition) never
  // calls `ref` after the element is torn down — using ref in dispose throws
  // "Cannot use ref after the widget was disposed".
  late final StateController<String?> _playingCardId;
  late final CardsNotifier _cards;
  final CuratedTimingService _timings = CuratedTimingService();
  // Per-word audio start times (seconds) for curated stories; null for stories
  // without bundled timing, which fall back to a linear estimate.
  List<double>? _wordStarts;

  @override
  void initState() {
    super.initState();
    _playingCardId = ref.read(currentPlayingCardIdProvider.notifier);
    _cards = ref.read(cardsProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    var cards = ref.read(cardsProvider).valueOrNull;
    if (cards == null) {
      await ref.read(cardsProvider.notifier).loadCards();
      cards = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
    }
    final card = cards
        .where((candidate) => candidate.id == widget.cardId)
        .firstOrNull;
    if (card == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Story not found.';
        });
      }
      return;
    }
    final player = ref.read(audioPlayerProvider);
    try {
      await player.stop();
      final duration = await player.setFilePath(card.mediaPath);
      if (card.playbackPosition > 0) {
        await player.seek(Duration(milliseconds: card.playbackPosition));
      }
      _card = card.copyWith(
        durationMs: duration?.inMilliseconds ?? card.durationMs,
      );
      _player = player;
      _wordStarts = await _timings.wordStartsFor(card.id);
      _playingCardId.state = card.id;
      _stateSubscription = player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          _complete();
        }
        if (mounted) setState(() {});
      });
      _saveTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _savePosition(),
      );
      if (mounted) setState(() => _loading = false);
      unawaited(player.play());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This story could not be played.';
        });
      }
    }
  }

  Future<void> _savePosition({bool completed = false}) async {
    final card = _card;
    final player = _player;
    if (card == null || player == null) return;
    _card = card.copyWith(
      playbackPosition: completed ? 0 : player.position.inMilliseconds,
      durationMs: player.duration?.inMilliseconds ?? card.durationMs,
      lastPlayedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _cards.updateCard(_card!);
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;
    await _savePosition(completed: true);
    if (mounted) context.go('/story/${widget.cardId}/end');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _savePosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _stateSubscription?.cancel();
    if (!_completed) _savePosition();
    // Stop playback when leaving the player — save position first (reads the
    // player's position), then stop, so audio never keeps playing with no
    // visible control to stop it.
    _player?.stop();
    // Clear the "now playing" indicator, but defer it: leaving via context.go
    // disposes this screen during the next route's build, and mutating a
    // watched provider mid-build throws. A post-frame callback runs it once the
    // tree is settled.
    final playingCardId = _playingCardId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playingCardId.state = null;
    });
    super.dispose();
  }

  Future<void> _favorite() async {
    if (_card == null) return;
    _card = _card!.copyWith(isFavorite: !_card!.isFavorite);
    await ref.read(cardsProvider.notifier).updateCard(_card!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _NightLoadingScaffold();
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    if (_error != null || _card == null) {
      return Scaffold(
        backgroundColor: tokens.nightDeep,
        body: SafeArea(
          child: StErrorView(
            icon: Icons.menu_book_rounded,
            title: 'Story not found',
            message: _error ?? 'We couldn\'t open this story.',
            retryLabel: 'Back to stories',
            onRetry: () => context.go('/listen'),
          ),
        ),
      );
    }
    final player = _player!;
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Top action row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () async {
                      await _savePosition();
                      if (context.mounted) context.go('/listen');
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: tokens.moon),
                  ),
                  IconButton(
                    onPressed: _favorite,
                    tooltip: _card!.isFavorite
                        ? 'Remove from favorites'
                        : 'Save to favorites',
                    icon: Icon(
                      _card!.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: tokens.lantern,
                    ),
                  ),
                ],
              ),
            ),
            // Scene player
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, posSnap) {
                    final position = posSnap.data ?? Duration.zero;
                    final duration = player.duration ?? Duration.zero;
                    final maxMs = max(1, duration.inMilliseconds).toDouble();
                    final progress = (position.inMilliseconds.toDouble() / maxMs)
                        .clamp(0.0, 1.0);
                    return StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (context, stateSnap) {
                        final isPlaying = stateSnap.data?.playing ?? false;
                        final text = _card!.storyText ?? '';
                        final wordCount = tokenizeStory(text).length;
                        final durationMs = duration.inMilliseconds;
                        final int? highlightedWordIndex;
                        if (text.isEmpty || wordCount == 0) {
                          highlightedWordIndex = null;
                        } else if (_wordStarts != null) {
                          // Curated stories: drive the highlight from real
                          // ElevenLabs per-word timestamps.
                          highlightedWordIndex = wordIndexForTime(
                            _wordStarts!,
                            position.inMilliseconds / 1000.0,
                          );
                        } else if (_card!.wordStarts != null &&
                            _card!.wordStarts!.isNotEmpty) {
                          // Generated stories with backend-derived per-word
                          // timestamps: same helper, different data source.
                          highlightedWordIndex = wordIndexForTime(
                            _card!.wordStarts!,
                            position.inMilliseconds / 1000.0,
                          );
                        } else if (durationMs == 0) {
                          highlightedWordIndex = null;
                        } else {
                          // No timing (e.g. generated stories): estimate.
                          highlightedWordIndex = (progress * wordCount)
                              .floor()
                              .clamp(0, wordCount - 1);
                        }
                        return StScenePlayer(
                          title: _card!.title,
                          bodyText: _card!.storyText ?? '',
                          highlightedWordIndex: highlightedWordIndex,
                          isPlaying: isPlaying,
                          progress: progress,
                          elapsed: _clock(position),
                          total: _clock(duration),
                          // Tint the night background with the story's
                          // color as a soft top-down glow (rather than
                          // lerping to a muddy mid-tone). Harmonizes with
                          // the bedtime gradient while keeping a hint of
                          // the story's identity.
                          artPanel: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.alphaBlend(
                                    hexOrFallback(_card!.color)
                                        .withValues(alpha: 0.32),
                                    tokens.nightCard,
                                  ),
                                  tokens.nightDeep,
                                ],
                              ),
                            ),
                            child: Center(
                              child: StoryAvatar(
                                card: _card!,
                                conceptSize: 150,
                                pixelScale: 10,
                              ),
                            ),
                          ),
                          onPlayPause: () =>
                              player.playing ? player.pause() : player.play(),
                          onSeek: (value) => player.seek(
                            Duration(
                              milliseconds: (value * maxMs).round(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _clock(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class StoryEndScreen extends ConsumerWidget {
  const StoryEndScreen({super.key, required this.cardId});
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final cards = ref.watch(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final card = cards.where((candidate) => candidate.id == cardId).firstOrNull;
    // No more per-screen `Theme(data: StorytimeTheme.bedtime, ...)` wrap here
    // — the root theme (main.dart) already registers LanternTokens.night(),
    // so this screen reads it directly instead of forcing a redundant
    // sub-theme (see docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md §2).
    if (card == null) {
      return Scaffold(
        backgroundColor: tokens.nightDeep,
        body: SafeArea(
          child: StErrorView(
            icon: Icons.menu_book_rounded,
            title: 'Story not found',
            message: 'We couldn\'t find this story anymore.',
            retryLabel: 'Back home',
            onRetry: () => context.go('/home'),
          ),
        ),
      );
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: StoryAvatar(
                        card: card,
                        conceptSize: 112,
                        pixelScale: 7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'The end',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayLarge.copyWith(color: tokens.lantern),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: tokens.moonDim,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlowButton(
                      label: 'Play again',
                      leading: const Icon(Icons.replay),
                      onTap: () => context.go('/story/$cardId'),
                    ),
                    const SizedBox(height: 10),
                    LanternOutlineButton(
                      label: card.isFavorite
                          ? 'Saved to favorites'
                          : 'Save to favorites',
                      leading: Icon(
                        card.isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      onTap: () => ref
                          .read(cardsProvider.notifier)
                          .updateCard(
                            card.copyWith(isFavorite: !card.isFavorite),
                          ),
                    ),
                    const SizedBox(height: 10),
                    LanternOutlineButton(
                      label: 'Make another',
                      leading: const Icon(Icons.auto_awesome),
                      onTap: () {
                        ref.read(storyDraftProvider.notifier).reset();
                        ref.read(storyDraftProvider.notifier).shuffleAll();
                        context.go('/compose');
                      },
                    ),
                    const SizedBox(height: 4),
                    LanternOutlineButton(
                      label: 'Back home',
                      onTap: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StorytimeParentDashboard extends StatelessWidget {
  const StorytimeParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        title: Text('Grown-up dashboard', style: TextStyle(color: tokens.moon)),
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: Icon(Icons.close, color: tokens.moon),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const LanternSectionHeader(title: 'Storytime settings'),
              const SizedBox(height: 18),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.child_care, tokens: tokens),
                title: 'Child profile',
                subtitle: 'Name, age, and avatar',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/child'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.menu_book_outlined, tokens: tokens),
                title: 'Manage stories',
                subtitle: 'Review or delete local stories',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/stories'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.mic_none_outlined, tokens: tokens),
                title: 'Add your own audio',
                subtitle: 'Record a voice or upload a file',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/add-audio'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.manage_accounts_outlined, tokens: tokens),
                title: 'Account',
                subtitle: 'Email, password, and sign out',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/account'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.pin_outlined, tokens: tokens),
                title: 'Parent PIN',
                subtitle: 'Change the grown-up access code',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/change-pin'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.privacy_tip_outlined, tokens: tokens),
                title: 'Privacy and diagnostics',
                subtitle: 'Review data handling and consent',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/privacy'),
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: _DashboardGlyph(icon: Icons.record_voice_over_outlined, tokens: tokens),
                title: 'Family voices',
                subtitle: 'Record or clone a familiar voice',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: () => context.go('/parent/family-voices'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular icon glyph used as `LanternRow.leading` across the
/// dashboard entries — mirrors the old `_DashboardEntry`'s `CircleAvatar`
/// treatment (ember tint → `lantern` tint) so the row's leading visual
/// keeps its shape/spacing, just recolored to Lantern tokens.
class _DashboardGlyph extends StatelessWidget {
  const _DashboardGlyph({required this.icon, required this.tokens});
  final IconData icon;
  final LanternTokens tokens;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: tokens.lantern.withValues(alpha: 0.12),
    child: Icon(icon, color: tokens.lantern, size: 20),
  );
}

class StorytimeAccountScreen extends ConsumerStatefulWidget {
  const StorytimeAccountScreen({super.key});
  @override
  ConsumerState<StorytimeAccountScreen> createState() =>
      _StorytimeAccountScreenState();
}

class _StorytimeAccountScreenState
    extends ConsumerState<StorytimeAccountScreen> {
  String? _message;
  bool _busy = false;

  Future<void> _reset() async {
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    if (email == null) return;
    await ref.read(authRepositoryProvider).sendPasswordReset(email);
    if (mounted) setState(() => _message = 'Password reset email sent.');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account and local stories?'),
        content: const Text(
          'This permanently removes the account, child profile, and every local story on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      final uid = auth.currentUser!.uid;
      await ref.read(storyGenerationRepositoryProvider).deleteAccountData();
      await ref.read(childProfileServiceProvider).delete(uid);
      final cards = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
      for (final card in cards) {
        await ref.read(cardsProvider.notifier).deleteCard(card.id);
      }
      await auth.signOut();
      if (mounted) context.go('/welcome');
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'The account could not be deleted. Please try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final user = ref.watch(authUserProvider).valueOrNull;
    final canReset = user?.providerIds.contains('password') == true;
    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        title: Text('Account', style: TextStyle(color: tokens.moon)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LanternRow(
                leading: Icon(Icons.mail_outline, color: tokens.moonDim),
                title: 'Email',
                subtitle: user?.email ?? 'Signed in with a provider',
              ),
              const SizedBox(height: 8),
              LanternRow(
                leading: Icon(Icons.verified_user_outlined, color: tokens.moonDim),
                title: 'Sign-in methods',
                subtitle: user?.providerIds.isNotEmpty == true
                    ? user!.providerIds.join(', ')
                    : 'Unknown',
              ),
              if (canReset) ...[
                const SizedBox(height: 8),
                LanternRow(
                  leading: Icon(Icons.lock_reset_outlined, color: tokens.moonDim),
                  title: 'Reset password',
                  subtitle: 'Send a reset link to your email',
                  trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                  onTap: _busy ? null : _reset,
                ),
              ],
              const SizedBox(height: 8),
              LanternRow(
                leading: Icon(Icons.logout, color: tokens.moonDim),
                title: 'Sign out',
                subtitle: 'Sign out of this device',
                trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                onTap: _busy
                    ? null
                    : () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/welcome');
                      },
              ),
              const SizedBox(height: 28),
              // Destructive action: `AppColors.destructive` → `hueCoral` per
              // spec §3. `LanternRow`'s title text is hardcoded to `moon`, so
              // the coral tint goes on the leading icon and trailing chevron
              // instead of the row's title.
              LanternRow(
                leading: Icon(Icons.delete_outline, color: tokens.hueCoral),
                title: 'Delete account and local data',
                subtitle: 'Removes the account and every local story',
                trailing: Icon(Icons.chevron_right, color: tokens.hueCoral),
                onTap: _busy ? null : _delete,
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(color: tokens.moonDim),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StorytimePrivacyScreen extends ConsumerStatefulWidget {
  const StorytimePrivacyScreen({super.key});

  @override
  ConsumerState<StorytimePrivacyScreen> createState() =>
      _StorytimePrivacyScreenState();
}

class _StorytimePrivacyScreenState
    extends ConsumerState<StorytimePrivacyScreen> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    ref.read(diagnosticsPreferencesServiceProvider).isEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await ref.read(diagnosticsPreferencesServiceProvider).setEnabled(value);
    await AnalyticsService.instance.setEnabled(value);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        title: Text('Privacy and diagnostics', style: TextStyle(color: tokens.moon)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const LanternSectionHeader(title: 'How we handle your data'),
              const SizedBox(height: 16),
              const _PrivacyPoint(
                icon: Icons.phone_android,
                title: 'Child profile stays here',
                body:
                    "The child's name, avatar, stories, favorites, and listening position stay encrypted on this device.",
              ),
              const SizedBox(height: 8),
              const _PrivacyPoint(
                icon: Icons.cloud_outlined,
                title: 'Story choices use the cloud',
                body:
                    "Character, scene, theme, plot, narrator, and age band are sent for story generation. The child's name is never sent.",
              ),
              const SizedBox(height: 8),
              const _PrivacyPoint(
                icon: Icons.delete_sweep_outlined,
                title: 'Temporary audio is deleted',
                body:
                    'Cloud audio is removed after the app imports it, or automatically within 24 hours.',
              ),
              const SizedBox(height: 8),
              const _PrivacyPoint(
                icon: Icons.no_accounts,
                title: 'No ads or child tracking',
                body:
                    'Storytime does not show ads to children or create child accounts.',
              ),
              const SizedBox(height: 20),
              LanternRow(
                leading: Icon(Icons.insights_outlined, color: tokens.lantern),
                title: 'Share anonymous diagnostics',
                subtitle:
                    'Sends crash and usage signals without child names, story text, email addresses, or audio links.',
                trailing: LanternToggle(
                  value: _enabled ?? false,
                  onChanged: _enabled == null ? (_) {} : _setEnabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return LanternRow(
      leading: Icon(icon, color: tokens.lantern),
      title: title,
      subtitle: body,
    );
  }
}
