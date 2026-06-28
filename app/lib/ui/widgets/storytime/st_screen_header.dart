import 'package:flutter/material.dart';
import 'st_section_header.dart';

/// Unified screen header for the kid flow (Home, wizard, Review, Listen).
///
/// Standardises the structure every kid-facing screen shares:
///   1. an optional control row — a back button (when [onBack] is set) on the
///      left and an optional [trailing] action on the right;
///   2. an optional [progress] slot (e.g. the wizard's step dots) between the
///      controls and the title;
///   3. the eyebrow / title / subtitle block, delegated to [StSectionHeader].
///
/// Title size is a deliberate choice, not forced uniform: landing/section
/// titles (Home, Listen) pass [largeTitle] to read larger than mid-flow step
/// titles (wizard, Review).
class StScreenHeader extends StatelessWidget {
  const StScreenHeader({
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

  /// Optional widget shown between the control row and the title block — the
  /// wizard passes its [StDots] here.
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
        StSectionHeader(
          eyebrow: eyebrow,
          title: title,
          sub: sub,
          largeTitle: largeTitle,
        ),
      ],
    );
  }
}
