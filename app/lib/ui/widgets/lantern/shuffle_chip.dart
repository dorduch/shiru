import 'package:flutter/material.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern "Shuffle" pill — re-rolls story slots (globally on the Composer
/// header, or per-slot inside the Slot Sheet; [label] distinguishes the two).
///
/// `nightCard` fill, `hush` 1px border, fully pill radius, 44pt minimum tap
/// target. On tap the refresh icon spins a full turn before [onTap] fires,
/// unless the platform requests reduced motion, in which case [onTap] fires
/// immediately with no animation (spec §4.6 — states must never rely on
/// motion alone).
class ShuffleChip extends StatefulWidget {
  const ShuffleChip({
    super.key,
    required this.onTap,
    this.label = 'Shuffle',
  });

  final VoidCallback onTap;

  /// Chip label — defaults to "Shuffle" for the global header control; pass
  /// a different string when reused for a per-slot shuffle context.
  final String label;

  @override
  State<ShuffleChip> createState() => _ShuffleChipState();
}

class _ShuffleChipState extends State<ShuffleChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      widget.onTap();
      return;
    }
    await _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.nightCard,
            borderRadius: AppRadius.full,
            border: Border.all(color: tokens.hush, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _controller,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: tokens.moon,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: 15,
                  color: tokens.moon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
