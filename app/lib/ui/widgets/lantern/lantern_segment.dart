import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern equivalent of `StSegment`
/// (`lib/ui/widgets/storytime/st_segment.dart`) — same pill-track shape and
/// spacing, only the token source changes. `StSegment` hardcodes a raw
/// `Colors.white` for the selected pill (a light-surface assumption that
/// doesn't carry to a dark ground); the selected pill here is `lantern`
/// filled with `nightDeep` text (the same on-accent contrast pairing
/// `GlowButton`/`StButton`'s ember variant already use), track is `nightCard`
/// with a `hush` border, unselected labels are `moonDim`.
class LanternSegment extends StatelessWidget {
  const LanternSegment({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.nightCard,
        borderRadius: AppRadius.full,
        border: Border.all(color: tokens.hush, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? tokens.lantern : Colors.transparent,
                borderRadius: AppRadius.full,
              ),
              child: Text(
                options[i],
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? tokens.nightDeep : tokens.moonDim,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
