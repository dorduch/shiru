import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticsPreferencesService {
  static const _key = 'storytime_diagnostics_consent';

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, enabled);
  }
}
