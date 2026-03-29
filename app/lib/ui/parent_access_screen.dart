import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/adult_gate_provider.dart';

class ParentAccessScreen extends ConsumerWidget {
  final String nextLocation;

  const ParentAccessScreen({super.key, required this.nextLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adultGateStatus = ref.watch(adultAgeVerifiedProvider);
    final isAuthenticated = ref.watch(parentAuthProvider);

    return adultGateStatus.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to open parent tools.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(adultAgeVerifiedProvider.notifier).reload(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (hasVerifiedAdult) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final nextPath = isAuthenticated
              ? nextLocation
              : hasVerifiedAdult
              ? '/pin'
              : '/age-check';
          context.go(
            Uri(
              path: nextPath,
              queryParameters: nextPath == nextLocation
                  ? null
                  : {'next': nextLocation},
            ).toString(),
          );
        });

        return const Scaffold(
          backgroundColor: Color(0xFFF6F7F8),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
