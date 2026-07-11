import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/family_voices_screens.dart';

/// A minimal router that hosts [VoiceCaptureIntroScreen] and absorbs
/// navigation to the invite-share route with a stub screen — mirrors
/// `add_audio_screens_test.dart`'s `_buildRouter` helper. A stub avoids
/// instantiating the real [VoiceInviteShareScreen], whose `initState` calls
/// the live `createVoiceInvite` Cloud Function callable.
GoRouter _buildRouter() => GoRouter(
  initialLocation: '/parent/family-voices/capture-intro',
  routes: [
    GoRoute(
      path: '/parent/family-voices/capture-intro',
      builder: (context, state) => const VoiceCaptureIntroScreen(
        voiceId: 'voice-1',
        name: 'Grandma Rose',
      ),
    ),
    GoRoute(
      path: '/parent/family-voices/capture',
      builder: (context, state) => const Scaffold(body: SizedBox()),
    ),
    GoRoute(
      path: '/parent/family-voices/upload',
      builder: (context, state) => const Scaffold(body: SizedBox()),
    ),
    GoRoute(
      path: '/parent/family-voices/invite',
      builder: (context, state) =>
          const Scaffold(body: Text('invite-stub-screen')),
    ),
  ],
);

void main() {
  testWidgets(
    'VoiceCaptureIntroScreen renders the invite option and navigates to it',
    (tester) async {
      final router = _buildRouter();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: StorytimeTheme.day,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three capture options are present.
      expect(find.text('Record now'), findsOneWidget);
      expect(find.text('Upload a clip'), findsOneWidget);
      expect(find.text('Invite someone to record'), findsOneWidget);
      expect(
        find.text('Send a link — they record in any browser.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Invite someone to record'));
      await tester.pumpAndSettle();

      // Tapping navigated to the invite route (stubbed here to avoid
      // exercising the real Cloud Functions callable in a widget test).
      expect(find.text('invite-stub-screen'), findsOneWidget);
    },
  );
}
