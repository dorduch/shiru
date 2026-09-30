import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/relative_reading.dart';
import '../services/relative_reading_repository.dart';
import 'storytime_providers.dart';

final relativeReadingRepositoryProvider = Provider<RelativeReadingRepository>((ref) {
  return RelativeReadingRepository();
});

/// Pending relative readings for the signed-in parent. Empty when signed out.
final pendingRelativeReadingsProvider =
    StreamProvider<List<RelativeReading>>((ref) {
  final user = ref.watch(authUserProvider).valueOrNull;
  final uid = user?.uid;
  if (uid == null) {
    return Stream.value(const <RelativeReading>[]);
  }
  return ref.watch(relativeReadingRepositoryProvider).watchPending(uid);
});
