import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';

/// Storytime button variants.
enum StButtonVariant {
  /// Ember gradient — primary CTA (ctaGradient fill, white text, glow shadow).
  ember,

  /// Dark — ink background, cream text.
  dark,

  /// Ghost — white background, line border, ink text.
  ghost,

  /// Line — transparent background, subtle light border (for dark surfaces).
  line,

  /// Soft — white background with a subtle card shadow.
  soft,
}

/// Primary Storytime button.
///
/// Usage:
/// ```dart
/// StButton(label: 'Create Story', onTap: () {});
/// StButton(label: 'Save', variant: StButtonVariant.dark, onTap: () {});
/// ```
class StButton extends StatefulWidget {
  const StButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = StButtonVariant.ember,
    this.fullWidth = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final StButtonVariant variant;

  /// If true, the button stretches to fill available horizontal space.
  final bool fullWidth;

  /// Optional icon shown to the left of the label.
  final Widget? leading;

  @override
  State<StButton> createState() => _StButtonState();
}

class _StButtonState extends State<StButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final cs = Theme.of(context).colorScheme;

    Widget content = _buildInner(tokens, cs);

    if (widget.fullWidth) {
      content = SizedBox(width: double.infinity, child: content);
    }

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: content,
        ),
      ),
    );
  }

  Widget _buildInner(StorytimeTokens tokens, ColorScheme cs) {
    switch (widget.variant) {
      case StButtonVariant.ember:
        return _GradientButton(
          label: widget.label,
          leading: widget.leading,
          gradient: tokens.ctaGradient,
          textColor: Colors.white,
          shadows: AppShadows.primaryGlow,
          radius: AppRadius.large,
        );

      case StButtonVariant.dark:
        return _SolidButton(
          label: widget.label,
          leading: widget.leading,
          bgColor: tokens.ink,
          textColor: tokens.cream,
          radius: AppRadius.large,
        );

      case StButtonVariant.ghost:
        return _SolidButton(
          label: widget.label,
          leading: widget.leading,
          bgColor: Colors.white,
          textColor: tokens.ink,
          border: Border.all(color: tokens.line, width: 1.5),
          radius: AppRadius.large,
        );

      case StButtonVariant.line:
        return _SolidButton(
          label: widget.label,
          leading: widget.leading,
          bgColor: Colors.transparent,
          textColor: tokens.cream,
          border: Border.all(color: tokens.cream.withValues(alpha: 0.4), width: 1.5),
          radius: AppRadius.large,
        );

      case StButtonVariant.soft:
        return _SolidButton(
          label: widget.label,
          leading: widget.leading,
          bgColor: Colors.white,
          textColor: tokens.ink,
          shadows: AppShadows.card,
          radius: AppRadius.large,
        );
    }
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.textColor,
    required this.radius,
    this.leading,
    this.shadows = const [],
  });

  final String label;
  final Widget? leading;
  final LinearGradient gradient;
  final Color textColor;
  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: _ButtonRow(label: label, leading: leading, color: textColor),
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.radius,
    this.leading,
    this.border,
    this.shadows = const [],
  });

  final String label;
  final Widget? leading;
  final Color bgColor;
  final Color textColor;
  final BoxBorder? border;
  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        border: border,
        boxShadow: shadows,
      ),
      child: _ButtonRow(label: label, leading: leading, color: textColor),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.label,
    required this.color,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          IconTheme(data: IconThemeData(color: color, size: 18), child: leading!),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTypography.bodyLarge.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
