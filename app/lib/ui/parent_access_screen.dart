import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/parent_flow_logic.dart';
import '../providers/auth_provider.dart';
import '../providers/adult_gate_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'widgets/storytime/storytime.dart';

class ParentAccessScreen extends ConsumerWidget {
  final String nextLocation;

  const ParentAccessScreen({super.key, required this.nextLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final adultGateStatus = ref.watch(adultAgeVerifiedProvider);
    final isAuthenticated = ref.watch(parentAuthProvider);

    return adultGateStatus.when(
      loading: () => Scaffold(
        backgroundColor: tokens.cream,
        body: Center(
          child: CircularProgressIndicator(color: tokens.ember),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: tokens.cream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Something went wrong. Let\'s try that again.',
                  style: AppTypography.titleMedium.copyWith(color: tokens.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(color: tokens.ink2),
                ),
                const SizedBox(height: 20),
                StButton(
                  label: 'Try Again',
                  variant: StButtonVariant.ember,
                  onTap: () =>
                      ref.read(adultAgeVerifiedProvider.notifier).reload(),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (hasVerifiedAdult) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final nextPath = resolveParentAccessDestination(
            isAuthenticated: isAuthenticated,
            hasVerifiedAdult: hasVerifiedAdult,
            nextLocation: nextLocation,
          );
          context.go(
            Uri(
              path: nextPath,
              queryParameters: nextPath == nextLocation
                  ? null
                  : {'next': nextLocation},
            ).toString(),
          );
        });

        return Scaffold(
          backgroundColor: tokens.cream,
          body: Center(
            child: CircularProgressIndicator(color: tokens.ember),
          ),
        );
      },
    );
  }
}
