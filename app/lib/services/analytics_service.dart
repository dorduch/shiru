import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  Future<void> ensureConsent() async {
    if (kDebugMode) {
      // Disable analytics in debug builds so development activity is never sent.
      await _run((analytics) => analytics.setAnalyticsCollectionEnabled(false));
    } else {
      // In release builds, analytics is enabled for crash/usage reporting.
      // Ensure this is disclosed in the app's privacy policy.
      await _run(
        (analytics) => analytics.setConsent(
          adStorageConsentGranted: false,
          adUserDataConsentGranted: false,
          analyticsStorageConsentGranted: true,
        ),
      );
    }
  }

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  Future<void> logCardCreated({required String method}) =>
      _logEvent(name: 'card_created', parameters: {'method': method});

  Future<void> logCardDeleted() => _logEvent(name: 'card_deleted');

  Future<void> logCardPlayed() => _logEvent(name: 'card_played');

  Future<void> logBulkImport({required int count}) =>
      _logEvent(name: 'bulk_import', parameters: {'count': count});

  Future<void> logCategoryCreated() => _logEvent(name: 'category_created');

  Future<void> logCategoryDeleted() => _logEvent(name: 'category_deleted');

  Future<void> logParentAreaEntered() =>
      _logEvent(name: 'parent_area_entered');

  Future<void> logPinChanged() => _logEvent(name: 'pin_changed');

  Future<void> logCategoryFilterUsed() =>
      _logEvent(name: 'category_filter_used');

  Future<void> logLibraryStats({
    required int cardCount,
    required int categoryCount,
  }) =>
      _logEvent(
        name: 'library_stats',
        parameters: {
          'card_count': cardCount,
          'category_count': categoryCount,
        },
      );

  Future<void> _logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) => _run(
        (analytics) => analytics.logEvent(name: name, parameters: parameters),
      );

  Future<void> _run(
    Future<void> Function(FirebaseAnalytics analytics) action,
  ) async {
    try {
      await action(FirebaseAnalytics.instance);
    } catch (_) {
      // Analytics is strictly non-critical. Ignore plugin/init failures.
    }
  }
}
