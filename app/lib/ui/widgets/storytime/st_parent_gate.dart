import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';

/// "Grown-ups only" PIN entry shell.
///
/// Renders a 4-digit dot display + a 3×4 numeric keypad.
/// [onCompleted] is called with the entered 4-digit string when the fourth
/// digit is entered. Validation is the caller's responsibility.
///
/// ```dart
/// StParentGate(
///   onCompleted: (pin) {
///     if (pin == '1234') nav.go('/parent');
///   },
/// )
/// ```
class StParentGate extends StatefulWidget {
  const StParentGate({
    super.key,
    required this.onCompleted,
    this.title = "Grown-ups only",
    this.subtitle = "Enter the 4-digit PIN to continue.",
  });

  final ValueChanged<String> onCompleted;
  final String title;
  final String subtitle;

  @override
  State<StParentGate> createState() => _StParentGateState();
}

class _StParentGateState extends State<StParentGate>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      widget.onCompleted(_pin);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _pin = '');
      });
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Icon(Icons.lock_outline_rounded, size: 36, color: tokens.ink2),
        const SizedBox(height: 12),
        Text(
          widget.title,
          style: AppTypography.headlineSmall.copyWith(color: tokens.ink),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Dot display
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final offset = _shakeCtrl.isAnimating
                ? math.sin(_shake.value * 3 * math.pi) * 8
                : 0.0;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? tokens.ember : AppColors.line2,
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 32),

        // Keypad
        _Keypad(onKey: _onKey, onDelete: _onDelete, tokens: tokens),
      ],
    );
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onKey,
    required this.onDelete,
    required this.tokens,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final StorytimeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 64);
            }
            return GestureDetector(
              onTap: key == '⌫' ? onDelete : () => onKey(key),
              child: Container(
                width: 72,
                height: 64,
                alignment: Alignment.center,
                child: key == '⌫'
                    ? Icon(Icons.backspace_outlined,
                        color: tokens.ink2, size: 22)
                    : Text(
                        key,
                        style: AppTypography.keypadDigit
                            .copyWith(color: tokens.ink),
                      ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
