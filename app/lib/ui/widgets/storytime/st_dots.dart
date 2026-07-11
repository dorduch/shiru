import 'package:flutter/material.dart';
import '../../../theme/lantern_tokens.dart';

/// Wizard step progress indicator.
///
/// The active step renders as an elongated pill; inactive steps are small
/// filled circles. All steps use the lantern accent color — inactive at
/// reduced opacity.
///
/// ```dart
/// StDots(totalSteps: 5, activeStep: 2)
/// ```
class StDots extends StatelessWidget {
  const StDots({
    super.key,
    required this.totalSteps,
    required this.activeStep,
  });

  /// Total number of steps (dots).
  final int totalSteps;

  /// Zero-indexed index of the currently active step.
  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final isActive = i == activeStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? tokens.lantern
                : tokens.lantern.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
