import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// On/off toggle switch matching the Storytime wireframe switch style.
///
/// ```dart
/// StToggle(value: _notifications, onChanged: (v) => setState(() => _notifications = v))
/// ```
class StToggle extends StatelessWidget {
  const StToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    final trackColor = WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) return tokens.ember;
      return tokens.line2;
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
