import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/ui/about_screen.dart';

void main() {
  testWidgets('about screen shows the main product story', (tester) async {
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
    expect(find.text('Made for familiar voices'), findsOneWidget);
    expect(
      find.textContaining('bedtime recording from a parent'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Private by default'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private by default'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Version 1.0.0'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0'), findsOneWidget);
  });
}
