import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';

/// Colored tile used on the kid home screen and narrator picker.
///
/// [big] variant is taller (used for wide/feature tiles).
class StTile extends StatefulWidget {
  const StTile({
    super.key,
    required this.label,
    this.sublabel,
    this.color,
    this.onTap,
    this.big = false,
    this.child,
  });

  final String label;
  final String? sublabel;

  /// Background color for the tile. Defaults to the theme surface.
  final Color? color;

  final VoidCallback? onTap;

  /// When true, the tile uses a taller layout.
  final bool big;

  /// Optional content widget overlaid in the tile body (e.g. pixel sprite).
  final Widget? child;

  @override
  State<StTile> createState() => _StTileState();
}

class _StTileState extends State<StTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final bg = widget.color ?? tokens.paper;

    final double minHeight = widget.big ? 140 : 96;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.large,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.child != null) ...[
                Expanded(
                  child: Center(child: widget.child!),
                ),
              ],
              Text(
                widget.label,
                style: AppTypography.titleLarge.copyWith(color: tokens.ink),
              ),
              if (widget.sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.sublabel!,
                  style: AppTypography.labelMedium.copyWith(color: tokens.ink2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
