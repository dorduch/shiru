import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_responsive.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Which flavor of voice a [VoiceCard] represents on the Composer's Voice
/// Shelf (spec §2.2 / §4.5).
enum VoiceCardVariant {
  /// A built-in narrator (Wizard Wally / Fairy Fern / Robo Ray) — has a
  /// personality one-liner and a Preview control.
  builtIn,

  /// A ready family voice — portrait card, relationship as the sub-line, no
  /// preview until family previews exist (see spec §7 open q2).
  family,

  /// A family voice still consented/queued/cloning: shimmering, non-tappable,
  /// "Getting ready…".
  processing,
}

/// One voice in the Composer's horizontal Voice Shelf — spec §2.2 / §4.5
/// "VoiceCard".
///
/// Kept deliberately dumb: [selected] and [previewPlaying] are supplied by
/// the caller (the Composer screen watches `storyDraftProvider` /
/// `narratorPreviewServiceProvider` and passes the resolved booleans down),
/// mirroring how `_NarratorPreviewButton` in the current wizard
/// (`lib/ui/storytime_screens.dart`) is driven from outside rather than
/// reaching into providers itself.
class VoiceCard extends StatelessWidget {
  const VoiceCard({
    super.key,
    required this.name,
    this.subline,
    required this.glyph,
    required this.variant,
    required this.selected,
    this.onTap,
    this.onPreview,
    this.previewPlaying = false,
    this.wellTint,
  });

  final String name;
  final String? subline;

  /// The glyph rendered inside the circular well — typically a
  /// [FamilyVoiceGlyph] for family voices, or a narrator's existing concept
  /// art for built-ins.
  final Widget glyph;

  final VoiceCardVariant variant;

  /// Whether this card is the currently-resolved narrator. Forced to a
  /// non-selected visual when [variant] is [VoiceCardVariant.processing]
  /// regardless of what's passed here (a processing voice can never be the
  /// active narrator).
  final bool selected;

  final VoidCallback? onTap;

  /// Plays/stops this voice's preview clip. Only rendered when [variant] is
  /// [VoiceCardVariant.builtIn] and this is non-null (family voices have no
  /// preview asset today; processing voices are never tappable).
  final VoidCallback? onPreview;

  /// Whether *this* card's preview is the one currently playing — drives the
  /// Preview/Playing pill label + icon. Caller derives this from
  /// `NarratorPreviewService.playing`.
  final bool previewPlaying;

  /// Glyph-well background tint for [VoiceCardVariant.builtIn] cards —
  /// typically a concept hue at reduced alpha (see
  /// `LanternTokens.slotFillFor`). Defaults to `lantern @ 18%` (the same
  /// fill family voices always use) when not supplied. Ignored for
  /// [VoiceCardVariant.family] and [VoiceCardVariant.processing], which have
  /// fixed well treatments per spec §4.5.
  final Color? wellTint;

  static const double _wellDiameter = 72;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final isProcessing = variant == VoiceCardVariant.processing;

    // Processing forces a non-selected visual — a card that isn't ready
    // can't be the active narrator no matter what the caller passes.
    final effectiveSelected = isProcessing ? false : selected;
    final effectiveSubline = isProcessing ? 'Getting ready…' : subline;
    final showPreview = variant == VoiceCardVariant.builtIn && onPreview != null;

    final size = AppResponsive.isCompact(context)
        ? const Size(108, 148)
        : const Size(128, 160);

    final wellColor = switch (variant) {
      VoiceCardVariant.family => tokens.lantern.withValues(alpha: 0.18),
      VoiceCardVariant.builtIn => wellTint ?? tokens.lantern.withValues(alpha: 0.18),
      VoiceCardVariant.processing => tokens.hush,
    };

    final borderColor = effectiveSelected ? tokens.lantern : tokens.hush;
    final borderWidth = effectiveSelected ? 2.5 : 1.0;
    final boxShadow = effectiveSelected
        ? [
            BoxShadow(
              color: tokens.lantern.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ]
        : const <BoxShadow>[];

    final label = effectiveSubline == null ? name : '$name, $effectiveSubline';

    final card = Container(
      // `minHeight` rather than a hard `height`: the spec's 108×148/128×160
      // is a target, not a hard cap. A built-in card (well 72 + two text
      // lines + a 44pt-tall preview pill) genuinely doesn't fit the compact
      // target height once you account for real padding/gaps, so this lets
      // that variant grow to fit its content instead of overflowing/
      // clipping, while family/processing cards (no pill) still land at
      // (or within a hair of) the nominal size. Width stays exactly fixed
      // so shelf cards line up evenly.
      constraints: BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.nightCard,
        borderRadius: AppRadius.large,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _wellDiameter,
            height: _wellDiameter,
            child: isProcessing
                ? _ProcessingGlyphWell(baseColor: wellColor, child: glyph)
                : ClipOval(
                    child: Container(
                      color: wellColor,
                      child: Center(child: glyph),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.moon,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (effectiveSubline != null) ...[
            const SizedBox(height: 2),
            Text(
              effectiveSubline,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 11.5,
                color: tokens.moonFaint,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (showPreview) ...[
            const SizedBox(height: 8),
            _PreviewPill(playing: previewPlaying, onTap: onPreview!),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      // Processing voices are announced as unavailable rather than merely
      // "not selected" — `enabled: false` (left `null`/inherited otherwise
      // so we don't clobber the ambient enabled state for interactive
      // cards).
      enabled: isProcessing ? false : null,
      selected: effectiveSelected,
      label: label,
      // Keep child semantics live for built-ins so the nested Preview
      // button stays independently reachable by screen readers — mirrors
      // `_NarratorRow`'s `excludeSemantics: !isBuiltIn` convention in
      // `lib/ui/storytime_screens.dart`.
      excludeSemantics: variant != VoiceCardVariant.builtIn,
      child: Opacity(
        opacity: isProcessing ? 0.6 : 1.0,
        child: IgnorePointer(
          // Belt-and-suspenders: processing cards are non-tappable even if
          // a caller passes a non-null onTap.
          ignoring: isProcessing,
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                card,
                if (effectiveSelected)
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
        ),
      ),
    );
  }
}

/// 44pt-tall Preview/Playing pill nested inside a [VoiceCard] for built-in
/// narrators. Its own [GestureDetector] means tapping it resolves in the
/// gesture arena before the card's outer [GestureDetector] — the same
/// nesting relationship `_NarratorPreviewButton` relies on today inside
/// `_NarratorRow` (`lib/ui/storytime_screens.dart`) to avoid also selecting
/// the row.
class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: tokens.lantern.withValues(alpha: 0.12),
          borderRadius: AppRadius.full,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 14,
              color: tokens.lantern,
            ),
            const SizedBox(width: 3),
            // Flexible + ellipsis: the pill sits inside a fixed-width card
            // (108pt on compact), so the label must clip gracefully rather
            // than overflow the RenderFlex if font metrics run wider than
            // expected (fallback fonts before `google_fonts` finishes
            // fetching, accessibility text scaling, etc) — never assume a
            // short two-word label always fits at any text scale.
            Flexible(
              child: Text(
                playing ? 'Playing' : 'Preview',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AppTypography.labelMedium.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.lantern,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glyph well for the [VoiceCardVariant.processing] state.
///
/// The spec (§4.5 / §4.6) calls for a shimmer *sweep* — a gradient traveling
/// across the well. That's implemented here as a simplified opacity pulse
/// (a `Container` fill fading between two alphas of the base [hush] color
/// on a ~1.4s round trip) rather than a literal traveling gradient: it reads
/// the same ("something is happening, not ready yet") at this small size for
/// meaningfully less animation-plumbing risk. Noted as a simplification per
/// the implementation plan's Task 2 allowance.
///
/// Respects `prefers-reduced-motion` (`MediaQuery.disableAnimations`): the
/// pulse stops and the well renders at a fixed mid-pulse alpha, since the
/// processing state is already distinguishable without motion (60% card
/// opacity, "Getting ready…" sub-line, non-tappable).
class _ProcessingGlyphWell extends StatefulWidget {
  const _ProcessingGlyphWell({required this.baseColor, required this.child});

  final Color baseColor;
  final Widget child;

  @override
  State<_ProcessingGlyphWell> createState() => _ProcessingGlyphWellState();
}

class _ProcessingGlyphWellState extends State<_ProcessingGlyphWell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      // 700ms forward + 700ms reverse ≈ the spec's ~1.4s sweep cycle.
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final alpha = 0.45 + (_pulse.value * 0.3);
        return ClipOval(
          child: Container(
            color: widget.baseColor.withValues(alpha: alpha),
            child: Center(child: widget.child),
          ),
        );
      },
    );
  }
}
