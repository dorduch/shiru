import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinNotifier extends StateNotifier<AsyncValue<String?>> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'parent_pin';

  PinNotifier() : super(const AsyncValue.loading()) {
    _loadPin();
  }

  Future<void> _loadPin() async {
    try {
      final pin = await _storage.read(key: _key);
      state = AsyncValue.data(pin);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updatePin(String newPin) async {
    await _storage.write(key: _key, value: newPin);
    state = AsyncValue.data(newPin);
  }
}

final pinProvider = StateNotifierProvider<PinNotifier, AsyncValue<String?>>(
  (ref) => PinNotifier(),
);
