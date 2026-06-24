import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/services/child_profile_service.dart';

import '../test_helpers/fake_key_value_store.dart';

void main() {
  test('profiles are encrypted-store records scoped by Firebase uid', () async {
    final store = FakeKeyValueStore();
    final service = ChildProfileService(store);
    const profile = ChildProfile(
      name: 'Sunny',
      ageBand: AgeBand.early,
      avatarSpriteKey: 'kid_2',
    );

    await service.save('uid-a', profile);

    expect((await service.load('uid-a'))?.name, 'Sunny');
    expect(await service.load('uid-b'), isNull);
    await service.delete('uid-a');
    expect(await service.load('uid-a'), isNull);
  });
}
