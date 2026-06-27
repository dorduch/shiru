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
        path: '/make/:step',
        builder: (context, state) =>
            StoryWizardScreen(step: state.pathParameters['step']!),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const StoryReviewScreen(),
      ),
      GoRoute(
        path: '/generate',
        builder: (context, state) => StoryGeneratingScreen(
          existingJobId: state.uri.queryParameters['jobId'],
        ),
      ),
      GoRoute(
        path: '/listen',
        builder: (context, state) => const StoryLibraryScreen(),
      ),
      GoRoute(
        path: '/story/:cardId/end',
        builder: (context, state) =>
            StoryEndScreen(cardId: state.pathParameters['cardId']!),
      ),
      GoRoute(
        path: '/story/:cardId',
        builder: (context, state) =>
            StoryPlayerScreen(cardId: state.pathParameters['cardId']!),
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
