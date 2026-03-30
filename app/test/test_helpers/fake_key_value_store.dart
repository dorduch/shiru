import 'package:shiru/services/key_value_store.dart';

class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([Map<String, String>? initialValues])
    : _values = Map<String, String>.from(initialValues ?? const {});

  final Map<String, String> _values;

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  String? operator [](String key) => _values[key];
}
