import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Shows the welcome popup as a modal dialog.
///
/// When [dismissible] is false (first launch), the user can only close the
/// dialog by tapping the "Get Started" button. Both barrier taps and the
/// system back gesture are blocked.
Future<void> showWelcomeDialog(
  BuildContext context, {
  bool dismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black54,
    builder: (context) => PopScope(
      canPop: dismissible,
      child: const WelcomeDialog(),
    ),
  );
}

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static const String personalNote =
      'I built this for my own kid — a player he controls himself, '
      'with no ads and no unsupervised content. Just stories from grandparents, '
      'favorite songs, and familiar voices.';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Shiru',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    personalNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _FeatureChip(
                    emoji: '🎙️',
                    label: 'Record stories from family',
                    background: Color(0xFFF0FDF4),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureChip(
                    emoji: '🎵',
                    label: 'Import songs & audiobooks',
                    background: Color(0xFFEFF6FF),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureChip(
                    emoji: '👧',
                    label: 'Kids play independently',
                    background: Color(0xFFFFF7ED),
                  ),
                  const SizedBox(height: 24),
                  _GetStartedButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color background;

  const _FeatureChip({
    required this.emoji,
    required this.label,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GetStartedButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Get Started',
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: AppColors.primaryShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'Get Started',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
