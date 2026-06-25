import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';

/// Storytime bottom nav bar item definition.
class StTabItem {
  const StTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bottom navigation bar matching the Storytime wireframe tab bar.
///
/// Active item uses [accent2] color; inactive uses [ink3].
///
/// ```dart
/// StTabBar(
///   items: const [
///     StTabItem(icon: Icons.home_rounded, label: 'Home'),
///     StTabItem(icon: Icons.headphones_rounded, label: 'Listen'),
///   ],
///   currentIndex: _tab,
///   onTap: (i) => setState(() => _tab = i),
/// )
/// ```
class StTabBar extends StatelessWidget {
  const StTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<StTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border(top: BorderSide(color: tokens.line, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10241F2E),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          final color = active ? AppColors.accent2 : tokens.ink3;
          final item = items[i];

          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 24),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: AppTypography.labelLarge.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
