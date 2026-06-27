import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// List row: circular avatar (initial or color) + title + subtitle
/// + trailing slot (chevron / lock pill / "soon" tag / custom).
class StRow extends StatelessWidget {
  const StRow({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarInitial,
    this.avatarColor,
    this.avatarImage,
    this.avatarChild,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Single character shown inside the avatar circle.
  final String? avatarInitial;

  /// Avatar background color; defaults to ember.
  final Color? avatarColor;

  /// Overrides [avatarInitial] when provided.
  final ImageProvider? avatarImage;

  /// Arbitrary widget (e.g. a [PixelSprite]) shown inside the avatar circle,
  /// clipped to the circle. Takes precedence over initial/image.
  final Widget? avatarChild;

  /// Widget placed at the trailing edge (chevron, pill, tag, etc.).
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: AppRadius.large,
        ),
        child: Row(
          children: [
            _Avatar(
              initial: avatarInitial,
              color: avatarColor ?? tokens.ember,
              image: avatarImage,
              child: avatarChild,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 16,
                      color: tokens.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          AppTypography.labelMedium.copyWith(color: tokens.ink2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({this.initial, required this.color, this.image, this.child});

  final String? initial;
  final Color color;
  final ImageProvider? image;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color,
      backgroundImage: child == null ? image : null,
      child: child != null
          ? ClipOval(
              child: SizedBox(width: 44, height: 44, child: child),
            )
          : (image == null && initial != null
              ? Text(
                  initial![0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                )
              : null),
    );
  }
}
