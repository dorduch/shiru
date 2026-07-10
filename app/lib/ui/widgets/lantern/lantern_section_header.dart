import 'package:flutter/material.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern equivalent of `StSectionHeader`
/// (`lib/ui/widgets/storytime/st_section_header.dart`) — title + optional
/// subtitle, left- or center-aligned.
///
/// `StSectionHeader` can't simply be re-skinned in place: it reads
/// `StorytimeTokens.ink`/`.ink2` directly rather than the mode-aware
/// `textPrimary`/`textSecondary` slots, and those two fields are identical
/// across day and bedtime (see `app_theme.dart`) — so its text is always dark,
/// which is illegible on the new permanent dark root theme. It still has
/// other cream-surface consumers elsewhere in the app that this rollout
/// hasn't reached yet, so the shared widget itself isn't touched; screens
/// migrated to Lantern use this widget instead.
class LanternSectionHeader extends StatelessWidget {
  const LanternSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.sub,
    this.centerAlign = false,
    this.largeTitle = false,
  });

  final String title;

  /// Small all-caps label rendered above [title] (e.g. "STEP 1 OF 2").
  /// Uppercased internally, same contract as `StSectionHeader.eyebrow`.
  final String? eyebrow;
  final String? sub;
  final bool centerAlign;

  /// When true the title renders one step larger (headlineMedium instead of
  /// headlineSmall) — used for landing/section titles that read larger than
  /// mid-flow step titles. Mirrors `StSectionHeader.largeTitle`.
  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final align = centerAlign ? TextAlign.center : TextAlign.start;
    final cross =
        centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(color: tokens.moonDim),
            textAlign: align,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          style: (largeTitle
                  ? AppTypography.headlineMedium
                  : AppTypography.headlineSmall)
              .copyWith(color: tokens.moon),
          textAlign: align,
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            style: AppTypography.bodyMedium.copyWith(color: tokens.moonDim),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}
