import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// Lantern equivalent of `StChip`
/// (`lib/ui/widgets/storytime/st_chips.dart`) — a small status pill.
///
/// `StChip` has a real (not just wrong-toned) bug: its label text color is
/// hardcoded to `StorytimeTokens.ink` with no prop to override it — only the
/// fill `color` is customizable. On a dark ground, a semantic status color
/// passed in as a translucent fill (e.g. `hueMeadow.withValues(alpha: 0.15)`)
/// still renders with dark `ink` text on top, which is illegible, not merely
/// off-brand.
///
/// `LanternChip` fixes this at the component level: both the fill tint and
/// the label color derive from the single [hue] param, so the text is always
/// legible against its own tinted fill regardless of which semantic hue
/// (`hueMeadow`/`hueCoral`/`lantern`/etc.) is passed in.
class LanternChip extends StatelessWidget {
  const LanternChip({
    super.key,
    required this.label,
    required this.hue,
    this.onTap,
  });

  final String label;

  /// Semantic hue driving both fill and text color — e.g.
  /// `tokens.hueMeadow`, `tokens.hueCoral`, `tokens.lantern`. Pass the hue
  /// itself, not a pre-alpha-blended fill.
  final Color hue;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.15),
          borderRadius: AppRadius.full,
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: hue),
        ),
      ),
    );
  }
}
