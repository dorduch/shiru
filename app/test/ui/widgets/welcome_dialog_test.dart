import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/ui/widgets/welcome_dialog.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required bool dismissible,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showWelcomeDialog(
                context,
                dismissible: dismissible,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('WelcomeDialog', () {
    testWidgets('shows heading, personal note, feature chips, and CTA', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: true);

      expect(find.text('Welcome to Shiru'), findsOneWidget);
      expect(
        find.textContaining('I built this for my own kid'),
        findsOneWidget,
      );
      expect(find.text('Record stories from family'), findsOneWidget);
      expect(find.text('Import songs & audiobooks'), findsOneWidget);
      expect(find.text('Kids play independently'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started button dismisses the dialog', (tester) async {
      await _openDialog(tester, dismissible: true);

      expect(find.byType(WelcomeDialog), findsOneWidget);
      await tester.ensureVisible(find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeDialog), findsNothing);
    });

    testWidgets('barrier tap dismisses when dismissible is true', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: true);
      expect(find.byType(WelcomeDialog), findsOneWidget);

      // Tap near the top-left corner, well outside the centered card.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsNothing);
    });

    testWidgets('barrier tap does NOT dismiss when dismissible is false', (
      tester,
    ) async {
      await _openDialog(tester, dismissible: false);
      expect(find.byType(WelcomeDialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsOneWidget);
    });
  });
}
