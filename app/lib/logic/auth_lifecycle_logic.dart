import 'package:flutter/widgets.dart';

bool shouldResetParentAuthForLifecycle({
  required AppLifecycleState state,
  required bool isExternalFileFlowActive,
}) {
  if (isExternalFileFlowActive) {
    return false;
  }

  return state == AppLifecycleState.paused ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.detached;
}
