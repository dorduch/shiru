import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/key_value_store.dart';

class PinNotifier extends StateNotifier<AsyncValue<String?>> {
  static const _key = 'parent_pin';
  final KeyValueStore _storage;

  PinNotifier(this._storage) : super(const AsyncValue.loading()) {
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
  (ref) => PinNotifier(ref.watch(keyValueStoreProvider)),
);
