import 'package:flutter/material.dart';
import '../../../theme/lantern_tokens.dart';

/// General-purpose selectable card — glyph + label, selectable via a tinted
/// fill and accent border on the selected state.
///
/// The Lantern design system's other selectable cards (`VoiceCard`,
/// `StorySlot`) are purpose-built for the Composer's exact shapes (spec
/// §4). This fills the gap the spec flagged: a general-purpose selectable
/// card for screens like `ChildSetupScreen`'s avatar picker, which used a
/// bespoke private `_AvatarChoice` widget (`storytime_screens.dart`) rather
/// than a shared component. Shape/spacing/radius copied 1:1 from
/// `_AvatarChoice`; only the token source and selection-tint value change
/// (`ember`/`paper`/`line` → `lantern`/`nightCard`/`hush`).
class LanternChoiceCard extends StatelessWidget {
  const LanternChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.glyph,
    this.width = 116,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Glyph shown above the label — avatar sprite, icon, whatever fits.
  final Widget glyph;

  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? tokens.lantern.withValues(alpha: 0.12)
                : tokens.nightCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? tokens.lantern : tokens.hush,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              glyph,
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.moon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
