import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/key_value_store.dart';

class AdultGateNotifier extends StateNotifier<AsyncValue<bool>> {
  static const _key = 'adult_gate_verified';
  final KeyValueStore _storage;

  AdultGateNotifier(this._storage) : super(const AsyncValue.loading()) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final storedValue = await _storage.read(key: _key);
      state = AsyncValue.data(storedValue == 'true');
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _loadStatus();
  }

  Future<void> markVerified() async {
    await _storage.write(key: _key, value: 'true');
    state = const AsyncValue.data(true);
  }
}

final adultAgeVerifiedProvider =
    StateNotifierProvider<AdultGateNotifier, AsyncValue<bool>>(
      (ref) => AdultGateNotifier(ref.watch(keyValueStoreProvider)),
    );
