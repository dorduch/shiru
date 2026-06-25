import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// Segmented control used in Content & Safety and similar screens.
///
/// ```dart
/// StSegment(
///   options: ['Off', 'On', 'Ask'],
///   selectedIndex: 1,
///   onChanged: (i) => setState(() => _sel = i),
/// )
/// ```
class StSegment extends StatelessWidget {
  const StSegment({
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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.line,
        borderRadius: AppRadius.full,
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
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: AppRadius.full,
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                options[i],
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? tokens.ink : tokens.ink2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
