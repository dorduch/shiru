import 'dart:convert';

import '../models/storytime_models.dart';
import 'key_value_store.dart';

class ChildProfileService {
  ChildProfileService(this._store);

  final KeyValueStore _store;

  String _key(String uid) => 'storytime_child_profile_$uid';

  Future<ChildProfile?> load(String uid) async {
    final encoded = await _store.read(key: _key(uid));
    if (encoded == null || encoded.isEmpty) return null;
    return ChildProfile.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  Future<void> save(String uid, ChildProfile profile) =>
      _store.write(key: _key(uid), value: jsonEncode(profile.toJson()));

  Future<void> delete(String uid) => _store.delete(key: _key(uid));
}
