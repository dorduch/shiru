import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_responsive.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern primary CTA button — the Composer's "Tell tonight's story" button
/// and any other primary call to action in the Lantern visual language.
///
/// Full-width, `ctaGradient` fill, `nightDeep` label (white fails AA on the
/// light end of the gradient — see spec §4.2), fully pill radius, and a soft
/// lantern glow in place of a drop shadow (spec §4.4).
///
/// [onTap] is nullable: pass `null` to disable (dims to 50% opacity and
/// reports `Semantics(enabled: false)`, matching `LanternOutlineButton`'s
/// contract). The Composer's own CTA is always live by construction (slots
/// are pre-shuffled, a narrator always has a default) so it never actually
/// exercises the disabled path — but other primary-CTA reuses (e.g.
/// `AgeGateScreen`'s cooldown-gated "Continue") legitimately need one, and
/// should pass `null` directly rather than wrapping this widget in
/// `Opacity`/`IgnorePointer`, which loses proper disabled semantics for
/// screen readers.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;

  /// Optional icon shown to the left of the label.
  final Widget? leading;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final height = AppResponsive.buttonSize(context);
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? _onTapDown : null,
        onTapUp: enabled ? _onTapUp : null,
        onTapCancel: enabled ? _onTapCancel : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  gradient: tokens.ctaGradient,
                  borderRadius: AppRadius.full,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.lantern.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leading != null) ...[
                        IconTheme(
                          data: IconThemeData(color: tokens.nightDeep, size: 18),
                          child: widget.leading!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Flexible + ellipsis: a Row's non-flex children get
                      // unbounded max width along the main axis, so a bare
                      // Text here ignores the button's real width and
                      // overflows on narrow phones (confirmed at 375px with
                      // this widget's own production label + leading icon).
                      // Flexible lets it shrink to the available space instead.
                      Flexible(
                        child: Text(
                          widget.label,
                          // Closest available match to the spec's Baloo 2
                          // display face: AppTypography doesn't expose Baloo 2,
                          // so reuse titleMedium (Inter 18) bumped to w700
                          // rather than hardcoding a one-off style.
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.nightDeep,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
