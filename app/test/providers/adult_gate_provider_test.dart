import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/providers/adult_gate_provider.dart';
import 'package:shiru/services/key_value_store.dart';

import '../test_helpers/fake_key_value_store.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('AdultGateNotifier', () {
    test('loads false when verification has not been saved', () async {
      final store = FakeKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(adultAgeVerifiedProvider);
      await _flushAsync();

      expect(container.read(adultAgeVerifiedProvider).value, isFalse);
    });

    test('persists verification when marked', () async {
      final store = FakeKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(adultAgeVerifiedProvider.notifier).markVerified();

      expect(container.read(adultAgeVerifiedProvider).value, isTrue);
      expect(store['adult_gate_verified'], 'true');
    });
  });
}
