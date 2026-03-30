import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/providers/pin_provider.dart';
import 'package:shiru/services/key_value_store.dart';

import '../test_helpers/fake_key_value_store.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('PinNotifier', () {
    test('loads a previously saved pin', () async {
      final store = FakeKeyValueStore({'parent_pin': '2468'});
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(pinProvider);
      await _flushAsync();

      expect(container.read(pinProvider).value, '2468');
    });

    test('persists updated pins', () async {
      final store = FakeKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(pinProvider.notifier).updatePin('1357');

      expect(container.read(pinProvider).value, '1357');
      expect(store['parent_pin'], '1357');
    });
  });
}
