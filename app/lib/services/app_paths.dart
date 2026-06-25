import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Caches the app documents directory so media paths can be stored RELATIVE
/// (portable across iOS reinstalls, where the container UUID changes) and
/// resolved to absolute at load time.
class AppPaths {
  AppPaths._();
  static String _documentsPath = '';
  static String get documentsPath => _documentsPath;

  static Future<void> init() async {
    _documentsPath = (await getApplicationDocumentsDirectory()).path;
  }

  /// Stored value -> absolute path for the current container.
  /// Relative (no separator) -> join docs. Absolute that exists -> keep.
  /// Absolute that's stale -> re-root basename into current docs (self-heal).
  static String resolve(String stored) {
    if (stored.isEmpty) return stored;
    if (!stored.contains(p.separator) && !stored.contains('/')) {
      return p.join(_documentsPath, stored);
    }
    if (File(stored).existsSync()) return stored;
    return p.join(_documentsPath, p.basename(stored));
  }

  /// Absolute path -> value to persist. Files under docs -> basename only.
  /// Anything else -> unchanged (external/non-managed).
  static String relativize(String absolute) {
    if (absolute.isEmpty) return absolute;
    if (p.isWithin(_documentsPath, absolute)) return p.basename(absolute);
    return absolute;
  }
}
