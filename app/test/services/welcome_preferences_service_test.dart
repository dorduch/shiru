import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiru/services/welcome_preferences_service.dart';

void main() {
  group('WelcomePreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WelcomePreferencesService.resetForTesting();
    });

    test('hasSeenWelcome returns false when no value is set', () async {
      final service = WelcomePreferencesService.instance;
      expect(await service.hasSeenWelcome(), isFalse);
    });

    test('hasSeenWelcome returns true after markWelcomeSeen', () async {
      final service = WelcomePreferencesService.instance;
      await service.markWelcomeSeen();
      expect(await service.hasSeenWelcome(), isTrue);
    });

    test('markWelcomeSeen persists across new service reads', () async {
      await WelcomePreferencesService.instance.markWelcomeSeen();
      WelcomePreferencesService.resetForTesting();
      expect(
        await WelcomePreferencesService.instance.hasSeenWelcome(),
        isTrue,
      );
    });

    test('hasSeenWelcome returns false when SharedPreferences throws', () async {
      // Simulate failure by injecting a broken store via the testing seam.
      WelcomePreferencesService.resetForTesting();
      WelcomePreferencesService.debugSetPrefsLoader(() async {
        throw Exception('boom');
      });
      expect(
        await WelcomePreferencesService.instance.hasSeenWelcome(),
        isFalse,
      );
    });
  });
}
