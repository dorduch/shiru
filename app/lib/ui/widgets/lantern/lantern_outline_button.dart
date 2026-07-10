import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_responsive.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern secondary button — quiet outline, no gradient/glow.
///
/// `GlowButton` is deliberately single-purpose (the one always-live primary
/// CTA — see its doc comment), so it has no secondary variant. Screens with
/// a secondary action (e.g. "I already have an account", "Share", "Done")
/// use this instead of falling back to `StButton`, whose `ghost`/`soft`
/// variants hardcode a white fill that doesn't belong on the night ground.
class LanternOutlineButton extends StatefulWidget {
  const LanternOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;

  /// Null disables the button — dims it and reports `Semantics(enabled:
  /// false)`, matching `StButton`'s `onTap != null` contract (unlike
  /// `GlowButton`, which is deliberately always-enabled by design).
  final VoidCallback? onTap;

  final Widget? leading;

  @override
  State<LanternOutlineButton> createState() => _LanternOutlineButtonState();
}

class _LanternOutlineButtonState extends State<LanternOutlineButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);

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
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
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
                  color: Colors.transparent,
                  borderRadius: AppRadius.full,
                  border: Border.all(color: tokens.hush, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leading != null) ...[
                        IconTheme(
                          data: IconThemeData(color: tokens.moonDim, size: 18),
                          child: widget.leading!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.moonDim,
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
