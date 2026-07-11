import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/analytics_service.dart';
import 'logic/parent_flow_logic.dart';
import 'providers/auth_provider.dart';
import 'ui/add_audio_screens.dart';
import 'ui/age_gate_screen.dart';
import 'ui/pin_gate_screen.dart';
import 'ui/parent_access_screen.dart';
import 'ui/change_pin_screen.dart';
import 'ui/family_voices_screens.dart';
import 'ui/story_composer_screen.dart';
import 'ui/storytime_screens.dart';
import 'ui/widgets/storytime/component_gallery_screen.dart';

OnEnterResult _handleParentAreaTransition(
  WidgetRef ref,
  GoRouterState currentState,
  GoRouterState nextState,
) {
  final isLeavingParentArea = shouldResetParentAuth(
    currentLocation: currentState.uri.toString(),
    nextLocation: nextState.uri.toString(),
  );

  if (isLeavingParentArea) {
    ref.read(parentAuthProvider.notifier).state = false;
  }

  return const Allow();
}

String? _protectAdultRoute(WidgetRef ref, GoRouterState state) {
  return protectAdultRoute(
    isAuthenticated: ref.read(parentAuthProvider),
    nextLocation: state.uri.toString(),
  );
}

/// Cross-fade page for the day→dark seam (C5).
///
/// The kid flow runs on cream "day" surfaces (home, wizard, review) and then
/// crosses into the night-gradient "bedtime" surfaces (generating, player,
/// story-end). The default iOS push slides one over the other, producing a hard
/// cream↔night cut. A fade instead reads like dusk falling: the warm screen
/// dims into night. Applied only to the dark destinations, so day-to-day
/// navigation keeps the platform slide.
///
/// Trade-off: a custom transition drops the interactive edge-swipe-back, which
/// is fine here — every dark screen has an explicit back/home control.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
    child: child,
  );
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    observers: [AnalyticsService.instance.observer],
    onEnter: (context, currentState, nextState, router) =>
        _handleParentAreaTransition(ref, currentState, nextState),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const StorytimeLaunchScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const StorytimeWelcomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => StorytimeAuthScreen(
          createMode: state.uri.queryParameters['mode'] != 'signin',
        ),
      ),
      GoRoute(
        path: '/child-setup',
        builder: (context, state) => const ChildSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const StorytimeHomeScreen(),
      ),
      GoRoute(
        path: '/compose',
        builder: (context, state) => const StoryComposerScreen(),
      ),
      GoRoute(
        path: '/generate',
        pageBuilder: (context, state) => _fadePage(
          state,
          StoryGeneratingScreen(
            existingJobId: state.uri.queryParameters['jobId'],
          ),
        ),
      ),
      GoRoute(
        path: '/listen',
        builder: (context, state) => const StoryLibraryScreen(),
      ),
      GoRoute(
        path: '/story/:cardId/end',
        pageBuilder: (context, state) => _fadePage(
          state,
          StoryEndScreen(cardId: state.pathParameters['cardId']!),
        ),
      ),
      GoRoute(
        path: '/story/:cardId',
        pageBuilder: (context, state) => _fadePage(
          state,
          StoryPlayerScreen(cardId: state.pathParameters['cardId']!),
        ),
      ),
      // dev only — remove before prod
      GoRoute(
        path: '/dev/gallery',
        builder: (c, s) => const ComponentGalleryScreen(),
      ),
      GoRoute(
        path: '/parent-access',
        builder: (context, state) => ParentAccessScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/age-check',
        builder: (context, state) => AgeGateScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => PinGateScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/parent',
        redirect: (context, state) => _protectAdultRoute(ref, state),
        builder: (context, state) => const StorytimeParentDashboard(),
        routes: [
          GoRoute(
            path: 'child',
            builder: (context, state) =>
                const ChildSetupScreen(returnLocation: '/parent'),
          ),
          GoRoute(
            path: 'stories',
            builder: (context, state) =>
                const StoryLibraryScreen(parentMode: true),
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const StorytimeAccountScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const StorytimePrivacyScreen(),
          ),
          GoRoute(
            path: 'family-voices',
            builder: (context, state) => const FamilyVoicesScreen(),
            routes: [
              GoRoute(
                path: 'consent',
                builder: (context, state) => const VoiceConsentScreen(),
              ),
              GoRoute(
                path: 'capture-intro',
                builder: (context, state) {
                  final extra =
                      state.extra as Map<String, String>? ?? {};
                  return VoiceCaptureIntroScreen(
                    voiceId: extra['voiceId'] ?? '',
                    name: extra['name'] ?? 'this person',
                  );
                },
              ),
              GoRoute(
                path: 'capture',
                builder: (context, state) {
                  final extra =
                      state.extra as Map<String, String>? ?? {};
                  return GuidedCaptureScreen(
                    voiceId: extra['voiceId'] ?? '',
                    name: extra['name'] ?? 'this person',
                  );
                },
              ),
              GoRoute(
                path: 'upload',
                builder: (context, state) {
                  final extra =
                      state.extra as Map<String, String>? ?? {};
                  return VoiceUploadScreen(
                    voiceId: extra['voiceId'] ?? '',
                    name: extra['name'] ?? 'this person',
                  );
                },
              ),
              GoRoute(
                path: 'invite',
                builder: (context, state) {
                  final extra =
                      state.extra as Map<String, String>? ?? {};
                  return VoiceInviteShareScreen(
                    voiceId: extra['voiceId'] ?? '',
                    name: extra['name'] ?? 'this person',
                  );
                },
              ),
              GoRoute(
                path: 'ready',
                builder: (context, state) {
                  final extra =
                      state.extra as Map<String, String>? ?? {};
                  return VoiceReadyScreen(
                    voiceId: extra['voiceId'] ?? '',
                    name: extra['name'] ?? 'this person',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'change-pin',
            builder: (context, state) => const ChangePinScreen(),
          ),
          GoRoute(
            path: 'add-audio',
            builder: (context, state) => const AddAudioCaptureScreen(),
            routes: [
              GoRoute(
                path: 'details',
                builder: (context, state) => const AddAudioDetailsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'edit-audio/:id',
            builder: (context, state) => AddAudioDetailsScreen(
              editingCardId: state.pathParameters['id'],
              replacingAudio: state.uri.queryParameters['replaced'] == '1',
            ),
            routes: [
              GoRoute(
                path: 'replace',
                builder: (context, state) =>
                    AddAudioCaptureScreen(editingCardId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
