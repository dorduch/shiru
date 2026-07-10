import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/parent_flow_logic.dart';
import '../providers/auth_provider.dart';
import '../providers/adult_gate_provider.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'widgets/lantern/lantern.dart';

class ParentAccessScreen extends ConsumerWidget {
  final String nextLocation;

  const ParentAccessScreen({super.key, required this.nextLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final adultGateStatus = ref.watch(adultAgeVerifiedProvider);
    final isAuthenticated = ref.watch(parentAuthProvider);

    return adultGateStatus.when(
      loading: () => _LanternGroundScaffold(
        tokens: tokens,
        body: Center(
          child: CircularProgressIndicator(color: tokens.lantern),
        ),
      ),
      error: (error, _) => _LanternGroundScaffold(
        tokens: tokens,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Something went wrong. Let\'s try that again.',
                  style: AppTypography.titleMedium.copyWith(color: tokens.moon),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.bodySmall.copyWith(color: tokens.moonDim),
                ),
                const SizedBox(height: 20),
                GlowButton(
                  label: 'Try Again',
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

        return _LanternGroundScaffold(
          tokens: tokens,
          body: Center(
            child: CircularProgressIndicator(color: tokens.lantern),
          ),
        );
      },
    );
  }
}

/// Shared Lantern-night ground for this screen's three states (loading,
/// error, redirecting) — `nightMid → nightDeep` gradient, same as
/// `StoryComposerScreen`/`StoryGeneratingScreen`.
class _LanternGroundScaffold extends StatelessWidget {
  const _LanternGroundScaffold({required this.tokens, required this.body});

  final LanternTokens tokens;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(child: body),
      ),
    );
  }
}
