import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class KeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error) {
      if (!_isDuplicateItemError(error)) rethrow;

      // Recover stale iOS keychain entries left behind across reinstalls,
      // without deleting the current value unless the retry path is needed.
      await _storage.delete(key: key);
      await _storage.write(key: key, value: value);
    }
  }
}

bool isDuplicateKeychainItemError(Object error) {
  return error is PlatformException && _isDuplicateItemError(error);
}

bool _isDuplicateItemError(PlatformException error) {
  final code = error.code;
  final message = error.message ?? '';
  final details = '${error.details ?? ''}';

  return code.contains('-25299') ||
      message.contains('-25299') ||
      details.contains('-25299');
}

final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return SecureKeyValueStore();
});
