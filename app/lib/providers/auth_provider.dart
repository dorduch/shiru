import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screenshot_mode.dart';

/// True when the parent has successfully entered the PIN in this session.
/// Reset to false when the app is backgrounded.
final parentAuthProvider = StateProvider<bool>((ref) => kStoreScreenshotMode);

/// True while an OS-managed file picker or share sheet is temporarily covering
/// the app, so parent auth should not be reset on background transitions.
final parentAuthExternalFileFlowProvider = StateProvider<bool>((ref) => false);

Future<T> preserveParentAuthDuringExternalFileFlow<T>(
  WidgetRef ref,
  Future<T> Function() action,
) async {
  ref.read(parentAuthExternalFileFlowProvider.notifier).state = true;
  try {
    return await action();
  } finally {
    ref.read(parentAuthExternalFileFlowProvider.notifier).state = false;
  }
}
