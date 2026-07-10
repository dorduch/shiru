import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/storytime_models.dart';
import '../providers/storytime_providers.dart';
import '../theme/app_radius.dart';
import '../theme/app_responsive.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'widgets/lantern/lantern.dart';
import 'widgets/storytime/st_concept_token.dart';

/// The modal bottom sheet opened when the child taps a Story Slot on the
/// Composer — spec §2.3 "The Slot Sheet".
///
/// Self-sufficient: reads/writes `storyDraftProvider` directly rather than
/// taking the current value or an `onSelect` callback, so the caller only
/// needs to know which [slot] was tapped:
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => StorySlotSheet(slot: slotKind),
/// );
/// ```
class StorySlotSheet extends ConsumerStatefulWidget {
  const StorySlotSheet({super.key, required this.slot});

  final SlotKind slot;

  @override
  ConsumerState<StorySlotSheet> createState() => _StorySlotSheetState();
}

class _StorySlotSheetState extends ConsumerState<StorySlotSheet> {
  /// Guards against a second tap firing a second dismiss-after-delay once a
  /// selection (tile tap or per-slot shuffle) has already been made.
  bool _dismissing = false;

  void _scheduleDismiss() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  void _select(VoidCallback apply, String label) {
    if (_dismissing) return;
    _dismissing = true;
    HapticFeedback.selectionClick();
    apply();
    ref.read(audioLabelServiceProvider).speak(label);
    _scheduleDismiss();
  }

  void _handleShuffle() {
    if (_dismissing) return;
    _dismissing = true;
    ref.read(storyDraftProvider.notifier).shuffleSlot(widget.slot);
    final label = _currentLabel(ref.read(storyDraftProvider));
    if (label != null) {
      ref.read(audioLabelServiceProvider).speak(label);
    }
    _scheduleDismiss();
  }

  String? _currentLabel(StoryDraft draft) => switch (widget.slot) {
    SlotKind.character => draft.character?.label,
    SlotKind.scene => draft.scene?.label,
    SlotKind.theme => draft.theme?.label,
    SlotKind.plot => draft.plot?.label,
  };

  String _titleFor(SlotKind slot) => switch (slot) {
    SlotKind.character => 'Who is our hero?',
    SlotKind.scene => 'Where does it happen?',
    SlotKind.theme => 'What is it about?',
    SlotKind.plot => 'What happens?',
  };

  Color _hueFor(SlotKind slot, LanternTokens tokens) => switch (slot) {
    SlotKind.character => tokens.hueSun,
    SlotKind.scene => tokens.hueSky,
    SlotKind.theme => tokens.hueBlossom,
    SlotKind.plot => tokens.hueLilac,
  };

  /// One tile per member of whichever concept enum [widget.slot] maps to.
  /// The four `Story*` enums don't share an interface, so this is a plain
  /// per-slot switch rather than a generic helper.
  List<Widget> _buildTiles(StoryDraft draft, Color tileFill) {
    switch (widget.slot) {
      case SlotKind.character:
        return StoryCharacter.values
            .map(
              (value) => _SlotOptionTile(
                label: value.label,
                glyph: StConceptToken(
                  value: value,
                  emoji: value.emoji,
                  background: false,
                  iconSize: 64,
                ),
                hueFill: tileFill,
                isCurrent: draft.character == value,
                onTap: () => _select(
                  () => ref
                      .read(storyDraftProvider.notifier)
                      .setCharacter(value),
                  value.label,
                ),
              ),
            )
            .toList();
      case SlotKind.scene:
        return StoryScene.values
            .map(
              (value) => _SlotOptionTile(
                label: value.label,
                glyph: StConceptToken(
                  value: value,
                  emoji: value.emoji,
                  background: false,
                  iconSize: 64,
                ),
                hueFill: tileFill,
                isCurrent: draft.scene == value,
                onTap: () => _select(
                  () => ref.read(storyDraftProvider.notifier).setScene(value),
                  value.label,
                ),
              ),
            )
            .toList();
      case SlotKind.theme:
        return StoryTheme.values
            .map(
              (value) => _SlotOptionTile(
                label: value.label,
                glyph: StConceptToken(
                  value: value,
                  emoji: value.emoji,
                  background: false,
                  iconSize: 64,
                ),
                hueFill: tileFill,
                isCurrent: draft.theme == value,
                onTap: () => _select(
                  () => ref.read(storyDraftProvider.notifier).setTheme(value),
                  value.label,
                ),
              ),
            )
            .toList();
      case SlotKind.plot:
        return StoryPlot.values
            .map(
              (value) => _SlotOptionTile(
                label: value.label,
                glyph: StConceptToken(
                  value: value,
                  emoji: value.emoji,
                  background: false,
                  iconSize: 64,
                ),
                hueFill: tileFill,
                isCurrent: draft.plot == value,
                onTap: () => _select(
                  () => ref.read(storyDraftProvider.notifier).setPlot(value),
                  value.label,
                ),
              ),
            )
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    // This sheet is documented as self-sufficient — it must render Lantern
    // night regardless of whichever ambient theme the *caller's* context
    // carries. `showModalBottomSheet` is typically invoked with a context
    // above any local `Theme` override the caller's own screen applies (see
    // `StoryComposerScreen`, which wraps itself in `StorytimeTheme.bedtime`
    // but calls `showModalBottomSheet` with its outer, unwrapped context), so
    // without this the sheet would silently inherit the app's ambient
    // day/bedtime mode instead of always being dark.
    return Theme(
      data: StorytimeTheme.bedtime,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    // Read fresh on each build via `ref.watch` so a per-slot shuffle visibly
    // moves the ring to the new tile before the 250ms auto-dismiss closes
    // the sheet.
    final draft = ref.watch(storyDraftProvider);

    // Slot Sheet tiles use a brighter 40% fill (vs. the main grid's 24%) —
    // `LanternTokens.slotFillFor` is hardcoded to 24% on night, so it can't
    // produce this sheet's alpha; the hue is taken at 40% directly here.
    final tileFill = _hueFor(widget.slot, tokens).withValues(alpha: 0.40);
    final crossAxisCount = AppResponsive.isCompact(context) ? 2 : 3;
    final gutter = AppResponsive.basePadding(context);
    final tiles = _buildTiles(draft, tileFill);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Container(
        decoration: BoxDecoration(
          gradient: tokens.nightGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.hush,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titleFor(widget.slot),
                        style: AppTypography.titleLarge.copyWith(
                          color: tokens.moon,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ShuffleChip(onTap: _handleShuffle, label: 'Shuffle'),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1,
                    children: tiles,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single option tile inside the [StorySlotSheet] grid.
///
/// Deliberately not [StorySlot] (which has no selection-ring vocabulary by
/// design — spec §4.5) and not [VoiceCard] (a different shape/context) —
/// this mirrors [VoiceCard]'s selected-state visual language (2.5pt
/// `lantern` ring + 22pt check badge) locally since neither existing
/// component fits.
class _SlotOptionTile extends StatelessWidget {
  const _SlotOptionTile({
    required this.label,
    required this.glyph,
    required this.hueFill,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final Widget glyph;
  final Color hueFill;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    final card = Container(
      decoration: BoxDecoration(
        color: hueFill,
        borderRadius: AppRadius.large,
        border: isCurrent
            ? Border.all(color: tokens.lantern, width: 2.5)
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 64, height: 64, child: glyph),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: tokens.moon,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: isCurrent,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(child: card),
            if (isCurrent)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: tokens.lantern,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: tokens.nightDeep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
