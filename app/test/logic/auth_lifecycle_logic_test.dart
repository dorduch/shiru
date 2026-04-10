import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/logic/auth_lifecycle_logic.dart';

void main() {
  group('shouldResetParentAuthForLifecycle', () {
    test('resets auth when the app backgrounds normally', () {
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.paused,
          isExternalFileFlowActive: false,
        ),
        isTrue,
      );
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.hidden,
          isExternalFileFlowActive: false,
        ),
        isTrue,
      );
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.detached,
          isExternalFileFlowActive: false,
        ),
        isTrue,
      );
    });

    test('does not reset auth during native file flows', () {
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.paused,
          isExternalFileFlowActive: true,
        ),
        isFalse,
      );
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.hidden,
          isExternalFileFlowActive: true,
        ),
        isFalse,
      );
    });

    test('does not reset auth for active foreground states', () {
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.resumed,
          isExternalFileFlowActive: false,
        ),
        isFalse,
      );
      expect(
        shouldResetParentAuthForLifecycle(
          state: AppLifecycleState.inactive,
          isExternalFileFlowActive: false,
        ),
        isFalse,
      );
    });
  });
}
