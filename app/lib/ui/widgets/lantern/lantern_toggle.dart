import 'package:flutter/material.dart';
import '../../../theme/lantern_tokens.dart';

/// Lantern equivalent of `StToggle`
/// (`lib/ui/widgets/storytime/st_toggle.dart`) — an on/off toggle switch.
///
/// `StToggle`'s "off" track reads `StorytimeTokens.line2`, a pale warm-tan
/// that's constant across day/bedtime — on the dark Lantern ground it renders
/// as a visible light switch-track, breaking the mode-aware palette.
/// `LanternToggle` mirrors `StToggle`'s exact shape/API, only sourcing its
/// track colors from `LanternTokens` instead: `hush` (hairlines/inactive
/// tracks) for "off", `lantern` (the accent) for "on".
///
/// ```dart
/// LanternToggle(value: _diagnostics, onChanged: (v) => setState(() => _diagnostics = v))
/// ```
class LanternToggle extends StatelessWidget {
  const LanternToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;

    final trackColor = WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) return tokens.lantern;
      return tokens.hush;
    });

    final thumbColor = WidgetStateProperty.all<Color>(Colors.white);

    return Switch(
      value: value,
      onChanged: onChanged,
      trackColor: trackColor,
      thumbColor: thumbColor,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
