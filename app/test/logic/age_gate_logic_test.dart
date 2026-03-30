import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/logic/age_gate_logic.dart';

void main() {
  group('calculateAge', () {
    test('returns age when birthday has already passed this year', () {
      expect(calculateAge(DateTime(2000, 3, 1), DateTime(2026, 3, 30)), 26);
    });

    test('returns age when birthday has not passed this year', () {
      expect(calculateAge(DateTime(2008, 10, 1), DateTime(2026, 3, 30)), 17);
    });
  });

  group('validateAdultBirthDate', () {
    final now = DateTime(2026, 3, 30);

    test('requires a birth date', () {
      expect(
        validateAdultBirthDate(null, now),
        'Enter your birth date to continue.',
      );
    });

    test('rejects underage users', () {
      expect(
        validateAdultBirthDate(DateTime(2010, 4, 1), now),
        'This area is only available to adults.',
      );
    });

    test('accepts users who are exactly 18', () {
      expect(validateAdultBirthDate(DateTime(2008, 3, 30), now), isNull);
    });
  });
}
