import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/relative_reading.dart';

void main() {
  test('fromMap normalizes status and displayName', () {
    final reading = RelativeReading.fromMap('abc', {
      'status': 'pending',
      'name': '  Grandma  ',
      'relationship': 'grandma',
      'storagePath': 'relative-readings/u/r/reading.webm',
      'mimeType': 'audio/webm',
      'durationSeconds': 75,
      'byteSize': 2048,
    });
    expect(reading.isPending, isTrue);
    expect(reading.displayName, 'Grandma');
    expect(reading.durationSeconds, 75);
  });

  test('unknown status falls back to pending', () {
    final reading = RelativeReading.fromMap('x', {
      'status': 'weird',
      'name': '',
      'relationship': 'uncle',
      'storagePath': 'p',
    });
    expect(reading.status, 'pending');
    expect(reading.displayName, 'uncle');
  });
}
