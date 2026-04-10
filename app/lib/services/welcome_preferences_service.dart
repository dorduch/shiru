import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps SharedPreferences for the one-shot "welcome popup seen" flag.
///
/// Centralizing the key string here prevents typo drift across callers.
class WelcomePreferencesService {
  WelcomePreferencesService._();

  static const String _welcomeSeenKey = 'welcome_seen';

  static WelcomePreferencesService _instance = WelcomePreferencesService._();
  static WelcomePreferencesService get instance => _instance;

  static Future<SharedPreferences> Function() _prefsLoader =
      SharedPreferences.getInstance;

  /// Returns true if the welcome popup has already been shown and dismissed.
  ///
  /// Returns false on any error (fail-open: better to re-show than to silently
  /// hide). Errors are reported via `debugPrint` so Crashlytics' Flutter error
  /// handler can pick them up in release builds.
  Future<bool> hasSeenWelcome() async {
    try {
      final prefs = await _prefsLoader();
      return prefs.getBool(_welcomeSeenKey) ?? false;
    } catch (error, stack) {
      debugPrint('WelcomePreferencesService.hasSeenWelcome failed: $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  /// Marks the welcome popup as seen. Silently swallows errors — failing to
  /// persist the flag just means the popup will appear again next launch,
  /// which is the better failure mode than crashing.
  Future<void> markWelcomeSeen() async {
    try {
      final prefs = await _prefsLoader();
      await prefs.setBool(_welcomeSeenKey, true);
    } catch (error, stack) {
      debugPrint('WelcomePreferencesService.markWelcomeSeen failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  // ─── Test seams ─────────────────────────────────────────────────────────

  @visibleForTesting
  static void resetForTesting() {
    _instance = WelcomePreferencesService._();
    _prefsLoader = SharedPreferences.getInstance;
  }

  @visibleForTesting
  static void debugSetPrefsLoader(Future<SharedPreferences> Function() loader) {
    _prefsLoader = loader;
  }
}
