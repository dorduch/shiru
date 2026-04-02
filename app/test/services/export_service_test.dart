import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/services/export_service.dart';

void main() {
  group('ExportService.sanitizeTitle', () {
    test('removes characters invalid in filenames', () {
      expect(
        ExportService.sanitizeTitle('Hello/World:File*Name'),
        equals('HelloWorldFileName'),
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        ExportService.sanitizeTitle('  My Recording  '),
        equals('My Recording'),
      );
    });

    test('collapses multiple internal spaces to single space', () {
      expect(
        ExportService.sanitizeTitle('Old   MacDonald'),
        equals('Old MacDonald'),
      );
    });

    test('handles all invalid chars: / \\ : * ? " < > |', () {
      expect(
        ExportService.sanitizeTitle(r'a/b\c:d*e?f"g<h>i|j'),
        equals('abcdefghij'),
      );
    });

    test('preserves normal title unchanged', () {
      expect(
        ExportService.sanitizeTitle("Old MacDonald's Farm"),
        equals("Old MacDonald's Farm"),
      );
    });

    test('falls back to "audio" for a title that becomes empty after sanitization', () {
      expect(
        ExportService.sanitizeTitle('///'),
        equals('audio'),
      );
    });
  });
}
