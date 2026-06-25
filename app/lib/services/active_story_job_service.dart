import 'key_value_store.dart';

class ActiveStoryJobService {
  ActiveStoryJobService(this._store);

  final KeyValueStore _store;

  String _key(String uid) => 'storytime_active_job_$uid';

  Future<String?> load(String uid) => _store.read(key: _key(uid));
  Future<void> save(String uid, String jobId) =>
      _store.write(key: _key(uid), value: jobId);
  Future<void> clear(String uid) => _store.delete(key: _key(uid));
}
