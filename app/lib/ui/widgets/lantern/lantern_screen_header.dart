import 'package:flutter/material.dart';
import 'lantern_section_header.dart';

/// Lantern equivalent of `StScreenHeader`
/// (`lib/ui/widgets/storytime/st_screen_header.dart`) — unified screen header
/// for Lantern-migrated screens.
///
/// Standardises the structure every migrated screen shares:
///   1. an optional control row — a back button (when [onBack] is set) on the
///      left and an optional [trailing] action on the right;
///   2. an optional [progress] slot (e.g. step dots) between the controls and
///      the title;
///   3. the eyebrow / title / subtitle block, delegated to
///      [LanternSectionHeader].
///
/// Purely structural, same as `StScreenHeader` — zero color logic of its own;
/// all color sourcing lives in [LanternSectionHeader].
class LanternScreenHeader extends StatelessWidget {
  const LanternScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.sub,
    this.onBack,
    this.trailing,
    this.progress,
    this.largeTitle = false,
  });

  final String title;
  final String? eyebrow;
  final String? sub;

  /// When non-null a back button is shown and calls this on tap.
  final VoidCallback? onBack;

  /// Optional right-aligned action in the control row (e.g. the Grown-up pill).
  final Widget? trailing;

  /// Optional widget shown between the control row and the title block.
  final Widget? progress;

  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    final hasControls = onBack != null || trailing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasControls)
          Row(
            children: [
              if (onBack != null) BackButton(onPressed: onBack),
              const Spacer(),
              ?trailing,
            ],
          ),
        if (progress != null) ...[
          Center(child: progress!),
          const SizedBox(height: 16),
        ],
        LanternSectionHeader(
          eyebrow: eyebrow,
          title: title,
          sub: sub,
          largeTitle: largeTitle,
        ),
      ],
    );
  }
}
