import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/logic/parent_flow_logic.dart';

void main() {
  group('routeWithNext', () {
    test('encodes the next location as a query parameter', () {
      expect(
        routeWithNext('/parent-access', '/parent/edit'),
        '/parent-access?next=%2Fparent%2Fedit',
      );
    });
  });

  group('isParentAreaLocation', () {
    test('matches parent routes', () {
      expect(isParentAreaLocation('/parent'), isTrue);
      expect(isParentAreaLocation('/parent/edit?id=1'), isTrue);
    });

    test('does not match kid routes', () {
      expect(isParentAreaLocation('/'), isFalse);
      expect(isParentAreaLocation('/pin'), isFalse);
    });
  });

  group('shouldResetParentAuth', () {
    test('resets auth when leaving the parent area', () {
      expect(
        shouldResetParentAuth(
          currentLocation: '/parent/categories',
          nextLocation: '/',
        ),
        isTrue,
      );
    });

    test('keeps auth when navigating within the parent area', () {
      expect(
        shouldResetParentAuth(
          currentLocation: '/parent',
          nextLocation: '/parent/edit',
        ),
        isFalse,
      );
    });
  });

  group('protectAdultRoute', () {
    test('redirects unauthenticated users to parent access', () {
      expect(
        protectAdultRoute(
          isAuthenticated: false,
          nextLocation: '/parent/bulk-import',
        ),
        '/parent-access?next=%2Fparent%2Fbulk-import',
      );
    });

    test('allows authenticated users through', () {
      expect(
        protectAdultRoute(isAuthenticated: true, nextLocation: '/parent'),
        isNull,
      );
    });
  });

  group('resolveParentAccessDestination', () {
    test('returns the parent destination for authenticated users', () {
      expect(
        resolveParentAccessDestination(
          isAuthenticated: true,
          hasVerifiedAdult: false,
          nextLocation: '/parent',
        ),
        '/parent',
      );
    });

    test('sends verified adults to the pin screen', () {
      expect(
        resolveParentAccessDestination(
          isAuthenticated: false,
          hasVerifiedAdult: true,
          nextLocation: '/parent',
        ),
        '/pin',
      );
    });

    test('sends unverified users to the age gate', () {
      expect(
        resolveParentAccessDestination(
          isAuthenticated: false,
          hasVerifiedAdult: false,
          nextLocation: '/parent',
        ),
        '/age-check',
      );
    });
  });
}
