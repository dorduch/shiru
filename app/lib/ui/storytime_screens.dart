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
import '../models/family_voice.dart';
import '../models/sprites.dart';
import '../models/storytime_models.dart';
import '../providers/audio_player_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/storytime_providers.dart';
import '../services/library_import_service.dart';
import '../services/starter_story_service.dart';
import '../services/story_generation_repository.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'widgets/storytime/storytime.dart';
import 'concept_icons.dart';
import 'pixel_sprite.dart';

class StorytimeLaunchScreen extends ConsumerWidget {
  const StorytimeLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(builder: (context) {
        final tokens = Theme.of(context).extension<StorytimeTokens>()!;
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
          color: tokens.night1,
          child: content,
        );
      }),
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

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _NightLoadingScaffold extends StatelessWidget {
  const _NightLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.night1,
      body: Center(
        child: CircularProgressIndicator(color: tokens.gold),
      ),
    );
  }
}

class _LaunchError extends StatelessWidget {
  const _LaunchError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Storytime could not start.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class StorytimeWelcomeScreen extends StatelessWidget {
  const StorytimeWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      body: SafeArea(
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
                      color: tokens.ember.withValues(alpha: 0.12),
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
                              color: tokens.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  StSectionHeader(
                    title: 'Storytime',
                    sub: 'Magical stories for little listeners.',
                    centerAlign: true,
                  ),
                  const SizedBox(height: 36),
                  StButton(
                    label: 'Get started',
                    fullWidth: true,
                    onTap: () => context.go('/auth?mode=create'),
                  ),
                  const SizedBox(height: 12),
                  StButton(
                    label: 'I already have an account',
                    variant: StButtonVariant.ghost,
                    fullWidth: true,
                    onTap: () => context.go('/auth?mode=signin'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'A grown-up creates the account. Child names and listening history stay on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.ink2, height: 1.4),
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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
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
                  StTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  StTextField(
                    controller: _password,
                    label: 'Password',
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.destructive),
                    ),
                  ],
                  const SizedBox(height: 18),
                  StButton(
                    label: _busy ? 'Please wait…' : 'Continue',
                    fullWidth: true,
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
                  StButton(
                    label: 'Continue with Apple',
                    variant: StButtonVariant.ghost,
                    fullWidth: true,
                    leading: const Icon(Icons.apple),
                    onTap: _busy
                        ? null
                        : () => _run(
                            ref.read(authRepositoryProvider).signInWithApple,
                          ),
                  ),
                  const SizedBox(height: 10),
                  StButton(
                    label: 'Continue with Google',
                    variant: StButtonVariant.ghost,
                    fullWidth: true,
                    leading: const Icon(Icons.account_circle_outlined),
                    onTap: _busy
                        ? null
                        : () => _run(
                            ref.read(authRepositoryProvider).signInWithGoogle,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "By continuing, the grown-up agrees that Storytime may send story choices and an age band to our generation providers. We never send the child's name.",
                    style: TextStyle(color: tokens.ink2, height: 1.45),
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
  Widget build(BuildContext context) => Scaffold(
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
                        (avatar) => _AvatarChoice(
                          label: avatar,
                          selected: _avatar == avatar,
                          onTap: () => setState(() => _avatar = avatar),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                StTextField(
                  controller: _name,
                  label: 'First name',
                ),
                const SizedBox(height: 20),
                StSegment(
                  options: AgeBand.values.map((b) => b.label).toList(),
                  selectedIndex: AgeBand.values.indexOf(_ageBand),
                  onChanged: (i) =>
                      setState(() => _ageBand = AgeBand.values[i]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ],
                const SizedBox(height: 28),
                StButton(
                  label: _busy ? 'Setting up…' : 'Done',
                  fullWidth: true,
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

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 116,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? tokens.ember.withValues(alpha: 0.12)
                : tokens.paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? tokens.ember : tokens.line,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              PixelSprite(sprite: autoAssignSprite(label), scale: 4.5),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center),
            ],
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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final profile = ref.watch(childProfileProvider).valueOrNull;
    final cards = ref.watch(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final resumable =
        cards.where((card) => card.playbackPosition > 5000).toList()..sort(
          (a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0),
        );
    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.go('/parent-access?next=/parent'),
                  icon: const Icon(Icons.lock_outline, size: 17),
                  label: const Text('Grown-up'),
                ),
              ),
              Text(
                'Hi ${profile?.name ?? 'there'}!',
                style: AppTypography.headlineMedium.copyWith(color: tokens.ink),
              ),
              Text(
                'What should we do today?',
                style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
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
                    final makeAction = StTile(
                      label: 'Make a Story',
                      sublabel: 'Build your own adventure',
                      color: AppColors.tilePlay,
                      big: true,
                      child: PixelSprite(
                        sprite: autoAssignSprite('magic story book'),
                        scale: 6,
                      ),
                      onTap: () {
                        ref.read(storyDraftProvider.notifier).reset();
                        context.go('/make/character');
                      },
                    );
                    final listenAction = StTile(
                      label: 'Listen',
                      sublabel: '${cards.length} stories',
                      color: AppColors.tileListen,
                      big: true,
                      child: PixelSprite(
                        sprite: autoAssignSprite('headphones story'),
                        scale: 6,
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
                              Expanded(flex: 2, child: makeAction),
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
    );
  }
}

class _ResumeStrip extends StatelessWidget {
  const _ResumeStrip({required this.card});
  final AudioCard card;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Keep going with ${card.title}',
    child: StRow(
      title: 'Keep going',
      subtitle: card.title,
      avatarInitial: '▶',
      avatarColor: AppColors.ember,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
      onTap: () => context.go('/story/${card.id}'),
    ),
  );
}


class StoryWizardScreen extends ConsumerWidget {
  const StoryWizardScreen({super.key, required this.step});
  final String step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final draft = ref.watch(storyDraftProvider);
    final index = _stepIndex(step);
    // For the narrator step, merge built-in narrators with ready family voices.
    List<_ChoiceItem> items;
    if (step == 'narrator') {
      final familyVoices = ref
          .watch(familyVoicesProvider)
          .valueOrNull
          ?.where((v) => v.status == FamilyVoiceStatus.ready)
          .toList() ??
          [];
      items = [
        ...NarratorKey.values
            .map((v) => _ChoiceItem(v, v.label, v.emoji, subtitle: v.description)),
        ...familyVoices.map(
          (v) => _ChoiceItem(
            v,
            v.name,
            '🎙️',
            subtitle: v.relationship,
            isFamilyVoice: true,
          ),
        ),
      ];
    } else {
      items = _itemsFor(step);
    }
    // selectedObj is used for comparison in _WizardChoice.
    // For family voices the item.value is a FamilyVoice, so we compare by id.
    final selectedObj = _selectedFor(draft, step);
    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BackButton(
                    onPressed: () {
                      if (index == 0) {
                        context.go('/home');
                      } else {
                        context.go('/make/${_steps[index - 1]}');
                      }
                    },
                  ),
                  const Spacer(),
                ],
              ),
              Center(child: StDots(totalSteps: _steps.length, activeStep: index)),
              const SizedBox(height: 16),
              StSectionHeader(
                eyebrow: 'Step ${index + 1} of ${_steps.length}',
                title: _questionFor(step),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 760
                        ? 3
                        : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = items[itemIndex];
                    // For family voice items compare by id; otherwise by value.
                    final isSelected = item.isFamilyVoice
                        ? (item.value is FamilyVoice &&
                              (item.value as FamilyVoice).id == selectedObj)
                        : item.value == selectedObj;
                    return _WizardChoice(
                      item: item,
                      selected: isSelected,
                      onTap: () {
                        _setSelection(ref, step, item.value);
                        ref.read(audioLabelServiceProvider).speak(item.label);
                      },
                    );
                  },
                ),
              ),
              StButton(
                label: 'Surprise me',
                variant: StButtonVariant.ghost,
                leading: const Icon(Icons.casino_outlined),
                fullWidth: true,
                onTap: () {
                  // For narrator: only surprise with built-in narrators.
                  final surprisePool = step == 'narrator'
                      ? items.where((i) => !i.isFamilyVoice).toList()
                      : items;
                  final pool = surprisePool.isEmpty ? items : surprisePool;
                  final item = pool[Random().nextInt(pool.length)];
                  _setSelection(ref, step, item.value);
                  ref
                      .read(audioLabelServiceProvider)
                      .speak('Surprise! ${item.label}');
                },
              ),
              const SizedBox(height: 10),
              StButton(
                label: 'Continue',
                fullWidth: true,
                onTap: selectedObj == null
                    ? null
                    : () {
                        context.go(
                          index == _steps.length - 1
                              ? '/review'
                              : '/make/${_steps[index + 1]}',
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _steps = ['character', 'scene', 'theme', 'plot', 'narrator'];
  int _stepIndex(String value) =>
      _steps.indexOf(value).clamp(0, _steps.length - 1);

  String _questionFor(String value) => switch (value) {
    'character' => 'Who is it about?',
    'scene' => 'Where does it happen?',
    'theme' => 'What is it about?',
    'plot' => 'What happens?',
    _ => 'Who tells the story?',
  };

  List<_ChoiceItem> _itemsFor(String value) => switch (value) {
    'character' =>
      StoryCharacter.values
          .map((v) => _ChoiceItem(v, v.label, v.emoji))
          .toList(),
    'scene' =>
      StoryScene.values.map((v) => _ChoiceItem(v, v.label, v.emoji)).toList(),
    'theme' =>
      StoryTheme.values.map((v) => _ChoiceItem(v, v.label, v.emoji)).toList(),
    'plot' =>
      StoryPlot.values.map((v) => _ChoiceItem(v, v.label, v.emoji)).toList(),
    _ =>
      NarratorKey.values
          .map((v) => _ChoiceItem(v, v.label, v.emoji, subtitle: v.description))
          .toList(),
  };

  Object? _selectedFor(StoryDraft draft, String value) => switch (value) {
    'character' => draft.character,
    'scene' => draft.scene,
    'theme' => draft.theme,
    'plot' => draft.plot,
    // For narrator: if a family voice is set return its id string so the
    // comparison `item.value == selected` works for FamilyVoice items.
    _ => draft.familyVoiceId ?? draft.narrator,
  };

  void _setSelection(WidgetRef ref, String value, Object selection) {
    final notifier = ref.read(storyDraftProvider.notifier);
    switch (value) {
      case 'character':
        notifier.setCharacter(selection as StoryCharacter);
      case 'scene':
        notifier.setScene(selection as StoryScene);
      case 'theme':
        notifier.setTheme(selection as StoryTheme);
      case 'plot':
        notifier.setPlot(selection as StoryPlot);
      default:
        if (selection is FamilyVoice) {
          notifier.setFamilyVoice(selection.id);
        } else {
          notifier.setNarrator(selection as NarratorKey);
        }
    }
  }
}

class _ChoiceItem {
  const _ChoiceItem(
    this.value,
    this.label,
    this.emoji, {
    this.subtitle,
    this.isFamilyVoice = false,
  });
  final Object value;
  final String label;
  final String emoji;
  final String? subtitle;
  final bool isFamilyVoice;
}

class _WizardChoice extends StatelessWidget {
  const _WizardChoice({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _ChoiceItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: item.subtitle == null
        ? item.label
        : '${item.label}, ${item.subtitle}',
    selected: selected,
    button: true,
    // Collapse the card's inner text into this one labelled button node (avoids
    // the doubled "Prince, Prince" read). Narrator cards keep their child
    // semantics so the nested "Preview" button stays reachable.
    excludeSemantics: item.value is! NarratorKey,
    child: StChoiceCard(
      name: item.label,
      selected: selected,
      onTap: onTap,
      // The concept tint fills the whole card so the icon's background and the
      // card's background are one seamless surface.
      tint: item.isFamilyVoice
          ? AppColors.cream
          : conceptTintFor(item.value),
      // Rich concept art: each concept renders a colorful storybook glyph on
      // the card's matching tint (with emoji fallback until the full set is
      // drawn). Family voices use the mic glyph.
      thumbnail: item.isFamilyVoice
          ? const Center(
              child: Icon(Icons.mic_rounded, size: 40, color: AppColors.ember),
            )
          : StConceptToken(
              value: item.value,
              emoji: item.emoji,
              background: false,
            ),
      // Preview lives below the card (outside the clipped 72×72 thumbnail box),
      // so it can no longer be clipped to a sliver.
      footer: item.value is NarratorKey
          ? Consumer(
              builder: (context, ref, _) => TextButton.icon(
                onPressed: () => ref
                    .read(narratorPreviewServiceProvider)
                    .play(item.value as NarratorKey),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Preview'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent2,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.labelMedium,
                ),
              ),
            )
          : null,
    ),
  );
}

class StoryReviewScreen extends ConsumerWidget {
  const StoryReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final draft = ref.watch(storyDraftProvider);
    if (!draft.isComplete) {
      _goAfterBuild(context, '/make/character');
      return const _LoadingScaffold();
    }
    final narratorLabel = draft.familyVoiceId != null
        ? 'Family voice'
        : draft.narrator!.label;
    final narratorEmoji = draft.familyVoiceId != null ? '🎙️' : draft.narrator!.emoji;
    final Object? narratorValue =
        draft.familyVoiceId != null ? null : draft.narrator;
    final choices = <(String, String, String, Object?)>[
      ('character', draft.character!.label, draft.character!.emoji, draft.character),
      ('scene', draft.scene!.label, draft.scene!.emoji, draft.scene),
      ('theme', draft.theme!.label, draft.theme!.emoji, draft.theme),
      ('plot', draft.plot!.label, draft.plot!.emoji, draft.plot),
      ('narrator', narratorLabel, narratorEmoji, narratorValue),
    ];
    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              StSectionHeader(
                eyebrow: 'Ready?',
                title: 'Your story',
                sub: 'Tap any choice to change it.',
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: choices.length,
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    return GestureDetector(
                      onTap: () => context.go('/make/${choice.$1}'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: conceptTintFor(choice.$4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tokens.ember, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            StConceptToken(
                              value: choice.$4,
                              emoji: choice.$3,
                              fill: false,
                              background: false,
                              iconSize: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                choice.$2,
                                style: AppTypography.titleLarge.copyWith(
                                  fontSize: 15,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              StButton(
                label: 'Make my story',
                fullWidth: true,
                leading: const Icon(Icons.auto_awesome),
                onTap: () => context.go('/generate'),
              ),
            ],
          ),
        ),
      ),
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
    setState(
      () => _status = switch (job.status) {
        StoryJobStatus.queued => 'Gathering a little magic…',
        StoryJobStatus.writing => 'Writing your story…',
        StoryJobStatus.checking => 'Making sure it feels just right…',
        StoryJobStatus.narrating => "Adding the storyteller's voice…",
        StoryJobStatus.ready => 'Saving your story…',
        StoryJobStatus.failed => 'The story magic fizzled this time.',
      },
    );
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
        spriteKey: autoAssignSprite(job.title!).id,
        audioPath: path,
        storyOrigin: StoryOrigin.generated,
        narratorKey: job.narratorKey,
        position: cards.length,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        storyText: job.story,
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
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(
        builder: (context) {
          final tokens = Theme.of(context).extension<StorytimeTokens>()!;
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
                        children: [
                          PixelSprite(sprite: autoAssignSprite('magic story'), scale: 7),
                          const SizedBox(height: 24),
                          Text(
                            // Don't keep the loading headline over a failure —
                            // swap to an error title when something went wrong.
                            _error == null ? _status : 'Oh no, a little hiccup',
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMedium.copyWith(color: tokens.cream),
                          ),
                          const SizedBox(height: 20),
                          if (_error == null)
                            LinearProgressIndicator(
                              minHeight: 8,
                              color: tokens.gold,
                              backgroundColor: tokens.cream.withValues(alpha: 0.18),
                            )
                          else ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.destructive,
                              ),
                            ),
                            const SizedBox(height: 18),
                            StButton(
                              label: 'Try again',
                              fullWidth: true,
                              onTap: () {
                                setState(() => _error = null);
                                _start();
                              },
                            ),
                            const SizedBox(height: 8),
                            StButton(
                              label: 'Back home',
                              variant: StButtonVariant.line,
                              fullWidth: true,
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
        },
      ),
    );
  }
}

class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key, this.parentMode = false});
  final bool parentMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final cards = ref.watch(cardsProvider);
    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        title: Text(
          parentMode ? 'Manage stories' : 'Listen',
          style: AppTypography.headlineSmall.copyWith(color: tokens.ink),
        ),
        leading: BackButton(
          onPressed: () => context.go(parentMode ? '/parent' : '/home'),
        ),
      ),
      body: SafeArea(
        child: cards.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: StButton(
              label: 'Try again',
              onTap: ref.read(cardsProvider.notifier).loadCards,
            ),
          ),
          data: (stories) {
            if (stories.isEmpty) {
              return Center(
                child: Text(
                  'No stories yet. Make one from Home.',
                  style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: stories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _StoryTile(card: stories[index], parentMode: parentMode),
            );
          },
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
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label:
        '${card.title}, ${card.storyOrigin == StoryOrigin.curated ? 'ready-made story' : 'your story'}',
    button: !parentMode,
    child: StRow(
      title: card.title,
      subtitle: card.storyOrigin == StoryOrigin.curated ? 'Ready-made story' : 'Your story',
      avatarColor: hexOrFallback(card.color),
      // Show the story's own pixel character instead of a blank color dot, so
      // each row has a real visual cue (not color alone).
      avatarChild: PixelSprite(
        sprite: card.spriteKey != null
            ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
            : autoAssignSprite(card.title),
        scale: 2.4,
      ),
      trailing: parentMode
          ? GestureDetector(
              onTap: () => _delete(context, ref),
              child: const Icon(Icons.delete_outline, color: AppColors.ink3, size: 20),
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
      onTap: parentMode ? null : () => context.go('/story/${card.id}'),
    ),
  );

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

  @override
  void initState() {
    super.initState();
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
      ref.read(currentPlayingCardIdProvider.notifier).state = card.id;
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
    await ref.read(cardsProvider.notifier).updateCard(_card!);
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
    ref.read(currentPlayingCardIdProvider.notifier).state = null;
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
    if (_loading) return const _LoadingScaffold();
    if (_error != null || _card == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Story not found.')));
    }
    final player = _player!;
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(
        builder: (context) {
          final tokens = Theme.of(context).extension<StorytimeTokens>()!;
          return Scaffold(
            backgroundColor: tokens.night1,
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
                          icon: Icon(Icons.arrow_back_rounded, color: tokens.cream),
                        ),
                        IconButton(
                          onPressed: _favorite,
                          tooltip: _card!.isFavorite
                              ? 'Remove from favorites'
                              : 'Save to favorites',
                          icon: Icon(
                            _card!.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: tokens.gold,
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
                              // NOTE: estimated word position — real per-word
                              // timing needs ElevenLabs timestamps
                              final text = _card!.storyText ?? '';
                              final words = text.split(RegExp(r'\s+'));
                              final durationMs = duration.inMilliseconds;
                              final int? highlightedWordIndex = (text.isEmpty ||
                                      durationMs == 0)
                                  ? null
                                  : (progress * words.length)
                                      .floor()
                                      .clamp(0, words.length - 1);
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
                                          AppColors.night3,
                                        ),
                                        AppColors.night1,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: PixelSprite(
                                      sprite:
                                          predefinedSprites[_card!.spriteKey] ??
                                          autoAssignSprite(_card!.title),
                                      scale: 10,
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
        },
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
    final cards = ref.watch(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final card = cards.where((candidate) => candidate.id == cardId).firstOrNull;
    if (card == null) {
      return const Scaffold(body: Center(child: Text('Story not found.')));
    }
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(
        builder: (context) {
          final tokens = Theme.of(context).extension<StorytimeTokens>()!;
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
                          PixelSprite(
                            sprite: autoAssignSprite('celebration stars'),
                            scale: 7,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'The end',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayLarge.copyWith(color: tokens.gold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            card.title,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: tokens.cream.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 28),
                          StButton(
                            label: 'Play again',
                            fullWidth: true,
                            leading: const Icon(Icons.replay),
                            onTap: () => context.go('/story/$cardId'),
                          ),
                          const SizedBox(height: 10),
                          StButton(
                            label: card.isFavorite
                                ? 'Saved to favorites'
                                : 'Save to favorites',
                            variant: StButtonVariant.line,
                            fullWidth: true,
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
                          StButton(
                            label: 'Make another',
                            variant: StButtonVariant.line,
                            fullWidth: true,
                            leading: const Icon(Icons.auto_awesome),
                            onTap: () {
                              ref.read(storyDraftProvider.notifier).reset();
                              context.go('/make/character');
                            },
                          ),
                          const SizedBox(height: 4),
                          StButton(
                            label: 'Back home',
                            variant: StButtonVariant.line,
                            fullWidth: true,
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
        },
      ),
    );
  }
}

class StorytimeParentDashboard extends StatelessWidget {
  const StorytimeParentDashboard({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Grown-up dashboard'),
      leading: IconButton(
        onPressed: () => context.go('/home'),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const StSectionHeader(title: 'Storytime settings'),
          const SizedBox(height: 18),
          _DashboardEntry(
            icon: Icons.child_care,
            title: 'Child profile',
            subtitle: 'Name, age, and avatar',
            onTap: () => context.go('/parent/child'),
          ),
          const SizedBox(height: 8),
          _DashboardEntry(
            icon: Icons.menu_book_outlined,
            title: 'Manage stories',
            subtitle: 'Review or delete local stories',
            onTap: () => context.go('/parent/stories'),
          ),
          const SizedBox(height: 8),
          _DashboardEntry(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            subtitle: 'Email, password, and sign out',
            onTap: () => context.go('/parent/account'),
          ),
          const SizedBox(height: 8),
          _DashboardEntry(
            icon: Icons.pin_outlined,
            title: 'Parent PIN',
            subtitle: 'Change the grown-up access code',
            onTap: () => context.go('/parent/change-pin'),
          ),
          const SizedBox(height: 8),
          _DashboardEntry(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy and diagnostics',
            subtitle: 'Review data handling and consent',
            onTap: () => context.go('/parent/privacy'),
          ),
          const SizedBox(height: 8),
          _DashboardEntry(
            icon: Icons.record_voice_over_outlined,
            title: 'Family voices',
            subtitle: 'Record or clone a familiar voice',
            onTap: () => context.go('/parent/family-voices'),
          ),
        ],
      ),
    ),
  );
}

class _DashboardEntry extends StatelessWidget {
  const _DashboardEntry({
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
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.line, width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: tokens.ember.withValues(alpha: 0.12),
              child: Icon(icon, color: tokens.ember, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelMedium.copyWith(color: tokens.ink2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.ink3),
          ],
        ),
      ),
      ),
    );
  }
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
    final user = ref.watch(authUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'Signed in with a provider'),
          ),
          ListTile(
            title: const Text('Sign-in methods'),
            subtitle: Text(user?.providerIds.join(', ') ?? ''),
          ),
          if (user?.providerIds.contains('password') == true)
            OutlinedButton(
              onPressed: _busy ? null : _reset,
              child: const Text('Send password reset email'),
            ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/welcome');
                  },
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _busy ? null : _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: const Text('Delete account and local data'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
        ],
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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const StSectionHeader(title: 'How we handle your data'),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.paper,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share anonymous diagnostics',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sends crash and usage signals without child names, story text, email addresses, or audio links.',
                        style: TextStyle(fontSize: 13, color: tokens.ink2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StToggle(
                  value: _enabled ?? false,
                  onChanged: _enabled == null ? (_) {} : _setEnabled,
                ),
              ],
            ),
          ),
        ],
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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return ListTile(
      leading: Icon(icon, color: tokens.ember),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: tokens.ink),
      ),
      subtitle: Text(body, style: TextStyle(color: tokens.ink2)),
    );
  }
}

class FamilyVoicesTeaserScreen extends ConsumerStatefulWidget {
  const FamilyVoicesTeaserScreen({super.key});
  @override
  ConsumerState<FamilyVoicesTeaserScreen> createState() =>
      _FamilyVoicesTeaserScreenState();
}

class _FamilyVoicesTeaserScreenState
    extends ConsumerState<FamilyVoicesTeaserScreen> {
  bool _joined = false;
  bool _busy = false;
  String? _error;
  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(storyGenerationRepositoryProvider)
          .joinFamilyVoiceWaitlist();
      if (mounted) setState(() => _joined = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not join right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Family voices')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelSprite(
                sprite: autoAssignSprite('family voice microphone'),
                scale: 7,
              ),
              const SizedBox(height: 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StSoonTag(),
                ],
              ),
              const SizedBox(height: 12),
              const StSectionHeader(
                title: 'A familiar voice, coming soon',
                sub: "Record or upload a family member's voice for story narration. This feature is not available in the MVP.",
                centerAlign: true,
              ),
              const SizedBox(height: 24),
              StButton(
                label: _joined
                    ? "You're on the waitlist"
                    : _busy
                    ? 'Joining…'
                    : 'Join the waitlist',
                fullWidth: true,
                onTap: _joined || _busy ? null : _join,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
