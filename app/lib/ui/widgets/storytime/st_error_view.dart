import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import 'st_button.dart';

/// Centered error / problem state: icon + heading + body + an actual retry
/// control. Replaces marooned one-line error sentences so a failure always
/// looks intentional and gives the user a way forward.
class StErrorView extends StatelessWidget {
  const StErrorView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: tokens.textTertiary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  AppTypography.headlineSmall.copyWith(color: tokens.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: tokens.textSecondary),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              StButton(
                label: retryLabel,
                variant: StButtonVariant.line,
                onTap: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
