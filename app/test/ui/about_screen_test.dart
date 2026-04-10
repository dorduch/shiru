import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shiru/ui/about_screen.dart';

void main() {
  testWidgets('about screen shows the main product story', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Shiru',
      packageName: 'app.shiru',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    final router = GoRouter(
      initialLocation: '/parent/about',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(path: '/parent/about', builder: (_, _) => const AboutScreen()),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('About Shiru'), findsOneWidget);
    expect(find.text('Welcome note'), findsOneWidget);
    expect(find.text('Why Shiru exists'), findsOneWidget);
    expect(
      find.textContaining('without turning listening time into a content feed'),
      findsOneWidget,
    );

    // Tapping the welcome note row opens the dialog.
    await tester.tap(find.text('Welcome note'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Shiru'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Dismiss it before continuing the rest of the test.
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Private by default'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private by default'), findsOneWidget);
    expect(
      find.textContaining('Stored on device', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Audio never uploaded', findRichText: true),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Version 1.0.0'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0'), findsOneWidget);
  });
}
