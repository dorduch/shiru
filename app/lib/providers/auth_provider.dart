import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screenshot_mode.dart';

/// True when the parent has successfully entered the PIN in this session.
/// Reset to false when the app is backgrounded.
final parentAuthProvider = StateProvider<bool>((ref) => kStoreScreenshotMode);
