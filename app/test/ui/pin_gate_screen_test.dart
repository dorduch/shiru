import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/providers/auth_provider.dart';
import 'package:shiru/services/key_value_store.dart';
import 'package:shiru/ui/pin_gate_screen.dart';

import '../test_helpers/fake_key_value_store.dart';

class _TestPinApp extends StatefulWidget {
  const _TestPinApp({required this.initialLocation});

  final String initialLocation;

  @override
  State<_TestPinApp> createState() => _TestPinAppState();
}

class _TestPinAppState extends State<_TestPinApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => PinGateScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const Scaffold(body: Text('parent')),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows create flow when no pin has been saved', (tester) async {
    final store = FakeKeyValueStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: const _TestPinApp(initialLocation: '/pin?next=%2Fparent'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a parent PIN'), findsOneWidget);
    expect(find.text('Pick a 4-digit PIN for parent tools'), findsOneWidget);
  });

  testWidgets('shows enter flow when a pin already exists', (tester) async {
    final store = FakeKeyValueStore({'parent_pin': '2468'});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: const _TestPinApp(initialLocation: '/pin?next=%2Fparent'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parents Only! 🔒'), findsOneWidget);
    expect(find.text('Enter 4-digit PIN'), findsOneWidget);
  });

  testWidgets('creates a new pin and navigates to the parent area', (
    tester,
  ) async {
    final store = FakeKeyValueStore();
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestPinApp(initialLocation: '/pin?next=%2Fparent'),
      ),
    );
    await tester.pumpAndSettle();

    await _enterPin(tester, '1357');
    await _enterPin(tester, '1357');

    expect(find.text('parent'), findsOneWidget);
    expect(container.read(parentAuthProvider), isTrue);
    expect(store['parent_pin'], '1357');
  });

  testWidgets('locks the keypad after five wrong attempts', (tester) async {
    final store = FakeKeyValueStore({'parent_pin': '2468'});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: const _TestPinApp(initialLocation: '/pin?next=%2Fparent'),
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 5; attempt++) {
      await _enterPin(tester, '1111');
    }

    expect(find.textContaining('Too many attempts.'), findsOneWidget);
    expect(find.textContaining('Try again in'), findsOneWidget);
  });
}
