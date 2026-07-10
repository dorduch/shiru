import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/family_voice.dart';
import '../models/storytime_models.dart';
import '../providers/storytime_providers.dart';
import '../theme/app_responsive.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'story_slot_sheet.dart';
import 'widgets/lantern/lantern.dart';
import 'widgets/storytime/st_concept_token.dart';

/// Fixed visual/traversal order of the four story-concept slots — also the
/// stagger order for the global-shuffle flip animation (spec §4.6: "global
/// shuffle staggers 4 cards 60ms apart").
const List<SlotKind> _slotOrder = [
  SlotKind.character,
  SlotKind.scene,
  SlotKind.theme,
  SlotKind.plot,
];

/// The Composer screen (`/compose`) — replaces the five-step wizard + review
/// screen with a single narrator-first screen. See
/// `docs/superpowers/specs/2026-07-10-story-composer-design.md` §2.2.
class StoryComposerScreen extends ConsumerStatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  ConsumerState<StoryComposerScreen> createState() =>
      _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  // ─── Slot "suggested" tracking ─────────────────────────────────────────
  // A slot is "suggested" (pre-filled by shuffle, not yet touched) until the
  // child opens its sheet or per-slot-shuffles it. Local widget state per
  // spec §2.2 / Task 5 — the provider itself has no concept of "touched".
  final Set<SlotKind> _suggestedSlots = {...SlotKind.values};

  // ─── Displayed slot values (decoupled from the provider so the global
  // shuffle can stagger the visual reveal 60ms apart per slot while the
  // underlying provider state already changed all at once) ───────────────
  StoryCharacter? _dispCharacter;
  StoryScene? _dispScene;
  StoryTheme? _dispTheme;
  StoryPlot? _dispPlot;

  /// True for exactly the duration of the synchronous `shuffleAll()` call
  /// (and the [ref.listen] callback it triggers) so [_onDraftChanged] can
  /// tell a global shuffle apart from a per-slot edit/shuffle — only the
  /// former staggers.
  bool _isGlobalShuffleInFlight = false;

  /// Guards the once-only default-narrator resolution on a fresh draft (Task
  /// 3 / spec §2.2). Set the moment resolution is scheduled, not when it
  /// completes, so a slow-resolving [lastNarratorProvider] doesn't cause the
  /// apply to be scheduled twice.
  bool _appliedDefaultNarrator = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(storyDraftProvider);
    _dispCharacter = initial.character;
    _dispScene = initial.scene;
    _dispTheme = initial.theme;
    _dispPlot = initial.plot;

    // Defensive fallback: Task 7 (Home tile reset()+shuffleAll() before
    // navigating here) isn't wired yet, and this screen is also reachable
    // directly (e.g. a temporary /dev/gallery link per the plan's Phase C).
    // Rather than render blank slots on an empty draft, fill them silently
    // (no TTS, no stagger — this isn't a user-driven shuffle event).
    //
    // Deferred to a post-frame callback: Riverpod forbids mutating provider
    // state synchronously during the widget-tree build phase (initState is
    // part of that phase), and calling `shuffleAll()` directly here throws
    // "Tried to modify a provider while the widget tree was building" —
    // confirmed by a widget test. `_onDraftChanged` (registered via
    // `ref.listen` in `build`) picks up the resulting change and populates
    // `_dispX` normally once it fires.
    if (initial.character == null ||
        initial.scene == null ||
        initial.theme == null ||
        initial.plot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final draft = ref.read(storyDraftProvider);
        if (draft.character == null ||
            draft.scene == null ||
            draft.theme == null ||
            draft.plot == null) {
          ref.read(storyDraftProvider.notifier).shuffleAll();
        }
      });
    }
  }

  // ─── Draft-change handling (staggered flip) ────────────────────────────

  void _onDraftChanged(StoryDraft? previous, StoryDraft next) {
    final wasGlobal = _isGlobalShuffleInFlight;
    _isGlobalShuffleInFlight = false;
    if (previous == null) return;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final changed = <SlotKind>[
      if (next.character != previous.character) SlotKind.character,
      if (next.scene != previous.scene) SlotKind.scene,
      if (next.theme != previous.theme) SlotKind.theme,
      if (next.plot != previous.plot) SlotKind.plot,
    ];
    if (changed.isEmpty) return;

    if (wasGlobal && !reduceMotion) {
      for (final kind in changed) {
        final delay = Duration(milliseconds: 60 * _slotOrder.indexOf(kind));
        Future.delayed(delay, () {
          if (!mounted) return;
          setState(() => _applyDisplayed(kind, next));
        });
      }
    } else {
      setState(() {
        for (final kind in changed) {
          _applyDisplayed(kind, next);
        }
      });
    }
  }

  void _applyDisplayed(SlotKind kind, StoryDraft next) {
    switch (kind) {
      case SlotKind.character:
        _dispCharacter = next.character;
      case SlotKind.scene:
        _dispScene = next.scene;
      case SlotKind.theme:
        _dispTheme = next.theme;
      case SlotKind.plot:
        _dispPlot = next.plot;
    }
  }

  // ─── Narrator selection ─────────────────────────────────────────────────

  void _applyDefaultNarrator(String resolvedKey) {
    if (resolvedKey.startsWith('family:')) {
      final id = resolvedKey.substring('family:'.length);
      ref.read(storyDraftProvider.notifier).setFamilyVoice(id);
      return;
    }
    for (final key in NarratorKey.values) {
      if (key.name == resolvedKey) {
        ref.read(storyDraftProvider.notifier).setNarrator(key);
        return;
      }
    }
  }

  void _selectNarrator(NarratorKey key) {
    ref.read(storyDraftProvider.notifier).setNarrator(key);
    _persistAndSpeak(key.label);
  }

  void _selectFamilyVoice(FamilyVoice voice) {
    ref.read(storyDraftProvider.notifier).setFamilyVoice(voice.id);
    _persistAndSpeak(voice.name);
  }

  void _persistAndSpeak(String spokenLabel) {
    final updated = ref.read(storyDraftProvider);
    ref
        .read(lastNarratorKeyProvider.notifier)
        .save(updated.resolvedNarratorKey);
    ref.read(audioLabelServiceProvider).speak(spokenLabel);
  }

  // ─── Shuffle ────────────────────────────────────────────────────────────

  void _onGlobalShuffle() {
    _isGlobalShuffleInFlight = true;
    final sentence = ref.read(storyDraftProvider.notifier).shuffleAll();
    ref.read(audioLabelServiceProvider).speak(sentence);
  }

  Future<void> _openSlotSheet(SlotKind slot) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySlotSheet(slot: slot),
    );
    if (!mounted) return;
    setState(() => _suggestedSlots.remove(slot));
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Registered once per build; Riverpod calls back synchronously whenever
    // `storyDraftProvider`'s state changes (including from the Slot Sheet,
    // which lives in a different widget subtree entirely).
    ref.listen<StoryDraft>(storyDraftProvider, _onDraftChanged);

    final draft = ref.watch(storyDraftProvider);
    final lastNarratorAsync = ref.watch(lastNarratorProvider);
    final familyVoicesAsync = ref.watch(familyVoicesProvider);

    // On first build of a genuinely fresh draft, resolve + apply the
    // persisted/default narrator (Task 3 / spec §2.2). Guarded so this only
    // ever fires once, and deferred to a post-frame callback since it's not
    // safe to mutate a provider mid-build.
    if (!_appliedDefaultNarrator &&
        draft.narrator == null &&
        draft.familyVoiceId == null) {
      final resolved = lastNarratorAsync.asData?.value;
      if (resolved != null) {
        _appliedDefaultNarrator = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyDefaultNarrator(resolved);
        });
      }
    }

    final familyVoices = familyVoicesAsync.asData?.value ?? const <FamilyVoice>[];
    final readyVoices = familyVoices
        .where((v) => v.status == FamilyVoiceStatus.ready)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final processingVoices = familyVoices
        .where((v) => v.status.isProcessing)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // This screen always renders Lantern-night regardless of the app's
    // ambient theme (ThemeMode/system). `Theme.of(context)` inside `build`
    // would otherwise resolve against the *ambient* theme, since the
    // `context` argument is an ancestor of the `Theme` node created below —
    // the `Builder` gives every LanternTokens lookup here a context that is
    // actually a descendant of it.
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(
        builder: (context) {
          final tokens = Theme.of(context).extension<LanternTokens>()!;
          final gutter = AppResponsive.basePadding(context);

          return Scaffold(
            backgroundColor: tokens.nightDeep,
            body: DecoratedBox(
              decoration: BoxDecoration(gradient: tokens.nightGradient),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, tokens),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: gutter,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(
                              "WHO'S READING TONIGHT?",
                              tokens,
                            ),
                            const SizedBox(height: 12),
                            _buildVoiceShelf(
                              context,
                              draft,
                              readyVoices,
                              processingVoices,
                              tokens,
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                _sectionLabel('THE STORY', tokens),
                                const Spacer(),
                                ShuffleChip(onTap: _onGlobalShuffle),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSlotGrid(context, tokens),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(gutter),
                      child: GlowButton(
                        label: "Tell tonight's story",
                        leading: const Icon(Icons.auto_awesome),
                        onTap: () => context.go('/generate'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, LanternTokens tokens) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.basePadding(context) - 4,
        AppResponsive.basePadding(context),
        AppResponsive.basePadding(context),
        0,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: tokens.moon),
            tooltip: 'Back',
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(width: 4),
          // Flexible + ellipsis: a bare Text in a Row can overflow even with
          // the Row's default mainAxisSize.max, since non-flex children still
          // get unbounded max-width along the main axis (the same footgun
          // fixed in GlowButton) — confirmed by a widget test at 390px width.
          Flexible(
            child: Text(
              "Tonight's story",
              style: AppTypography.displayMedium.copyWith(color: tokens.moon),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, LanternTokens tokens) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.4,
      color: tokens.moonDim,
    ),
  );

  // ─── Voice Shelf ────────────────────────────────────────────────────────

  Widget _buildVoiceShelf(
    BuildContext context,
    StoryDraft draft,
    List<FamilyVoice> readyVoices,
    List<FamilyVoice> processingVoices,
    LanternTokens tokens,
  ) {
    final previewService = ref.watch(narratorPreviewServiceProvider);

    return ValueListenableBuilder<NarratorKey?>(
      valueListenable: previewService.playing,
      builder: (context, playingKey, _) {
        final cards = <Widget>[
          for (final voice in readyVoices)
            VoiceCard(
              name: voice.name,
              subline: voice.relationship,
              glyph: const FamilyVoiceGlyph(),
              variant: VoiceCardVariant.family,
              selected: draft.familyVoiceId == voice.id,
              onTap: () => _selectFamilyVoice(voice),
            ),
          for (final voice in processingVoices)
            VoiceCard(
              name: voice.name,
              subline: voice.relationship,
              glyph: const FamilyVoiceGlyph(),
              variant: VoiceCardVariant.processing,
              selected: false,
            ),
          for (final key in NarratorKey.values)
            VoiceCard(
              name: key.label,
              subline: key.description,
              glyph: StConceptToken(
                value: key,
                emoji: key.emoji,
                background: false,
              ),
              variant: VoiceCardVariant.builtIn,
              selected: draft.narrator == key && draft.familyVoiceId == null,
              onTap: () => _selectNarrator(key),
              onPreview: () => previewService.play(key),
              previewPlaying: playingKey == key,
            ),
          if (readyVoices.isEmpty && processingVoices.isEmpty)
            const SizedBox(
              width: 260,
              child: Center(child: VoiceTeaser()),
            ),
        ];

        // A horizontal ListView gives every item a *tight* cross-axis
        // (height) constraint equal to this box's height, so it must fit the
        // tallest card variant — a built-in card (well + name + subline +
        // the 44pt preview pill) measures ~197pt regardless of breakpoint
        // (only its width changes between compact/regular per
        // `VoiceCard`'s own sizing), well past the family/processing
        // cards' ~140pt. Sized to the built-in's measured height + a small
        // buffer rather than `VoiceCard`'s nominal 148/160 target, which
        // only fits the pill-less variants and would clip/overflow the
        // built-ins.
        return SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }

  // ─── Story slot grid ────────────────────────────────────────────────────

  Widget _buildSlotGrid(BuildContext context, LanternTokens tokens) {
    final gutter = AppResponsive.basePadding(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      crossAxisSpacing: gutter,
      mainAxisSpacing: gutter,
      children: [
        _buildSlotCell(context, SlotKind.character, 'HERO', tokens.hueSun, tokens),
        _buildSlotCell(context, SlotKind.scene, 'WHERE', tokens.hueSky, tokens),
        _buildSlotCell(context, SlotKind.theme, 'ABOUT', tokens.hueBlossom, tokens),
        _buildSlotCell(
          context,
          SlotKind.plot,
          'WHAT HAPPENS',
          tokens.hueLilac,
          tokens,
        ),
      ],
    );
  }

  Widget _buildSlotCell(
    BuildContext context,
    SlotKind kind,
    String label,
    Color hue,
    LanternTokens tokens,
  ) {
    final Object? value = switch (kind) {
      SlotKind.character => _dispCharacter,
      SlotKind.scene => _dispScene,
      SlotKind.theme => _dispTheme,
      SlotKind.plot => _dispPlot,
    };
    if (value == null) return const SizedBox.shrink();

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final suggested = _suggestedSlots.contains(kind);

    final slot = StorySlot(
      label: label,
      valueName: _labelFor(value),
      glyph: StConceptToken(
        value: value,
        emoji: _emojiFor(value),
        background: false,
      ),
      hueFill: tokens.slotFillFor(hue, night: true),
      suggested: suggested,
      onTap: () => _openSlotSheet(kind),
    );

    // Flip per spec §4.6. A true 3D Y-axis flip via Transform proved fiddly
    // to keep legible at this card size (the mid-flip edge-on frame reads as
    // a blank sliver behind a solid-fill card), so this uses the plan's
    // explicitly-allowed simplification: a crossfade + scale-up, which still
    // reads as "the tile just changed" without motion/color being the sole
    // signal (the label/glyph content change carries that).
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('$kind-${_enumName(value)}'),
        child: slot,
      ),
    );
  }

  String _labelFor(Object value) => switch (value) {
    StoryCharacter v => v.label,
    StoryScene v => v.label,
    StoryTheme v => v.label,
    StoryPlot v => v.label,
    _ => value.toString(),
  };

  String _emojiFor(Object value) => switch (value) {
    StoryCharacter v => v.emoji,
    StoryScene v => v.emoji,
    StoryTheme v => v.emoji,
    StoryPlot v => v.emoji,
    _ => '',
  };

  String _enumName(Object value) => switch (value) {
    StoryCharacter v => v.name,
    StoryScene v => v.name,
    StoryTheme v => v.name,
    StoryPlot v => v.name,
    _ => value.toString(),
  };
}
