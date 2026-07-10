import 'package:flutter/material.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern empty-state teaser shown on the Voice Shelf only when zero family
/// voices exist (ready or processing) — spec §2.2 / §4.5.
///
/// A single, **non-interactive** line: no tap target, no `InkWell`/
/// `GestureDetector`, no button semantics. It plants the pivot's core intent
/// ("this could be your voice") without inviting a tap this screen can't
/// service (voice creation is a parent-zone action — see spec §2.2.1).
class VoiceTeaser extends StatelessWidget {
  const VoiceTeaser({super.key});

  /// Pulled out to a named constant so the copy is easy to find/update later
  /// — the spec notes this exact wording may need to match the real
  /// parent-zone settings label (spec §7, open question 4).
  static const String copy =
      "Grown-ups can add your family's voices in Settings.";

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Semantics(
      label: copy,
      container: true,
      // Explicitly not `button: true` — this is quiet supporting copy, not a
      // tappable affordance, and screen readers must not announce it as one.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: tokens.moonFaint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              copy,
              style: AppTypography.labelMedium.copyWith(
                fontSize: 12.5,
                color: tokens.moonFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
