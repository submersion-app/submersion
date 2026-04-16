import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

/// Provider for the [ReparseService] singleton.
final reparseServiceProvider = Provider<ReparseService>((ref) {
  final db = DatabaseService.instance.database;
  return ReparseService(db: db);
});

/// Provides raw data counts for all dive computer sources matching [computerId].
///
/// Returns a record with [withRawData] and [withoutRawData] counts.
final rawDataCountProvider =
    FutureProvider.family<({int withRawData, int withoutRawData}), String>((
      ref,
      computerId,
    ) {
      final service = ref.watch(reparseServiceProvider);
      return service.getRawDataCounts(computerId);
    });

/// Returns whether any [DiveDataSources] row for [diveId] has raw data stored.
final diveHasRawDataProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) {
  final service = ref.watch(reparseServiceProvider);
  return service.hasRawData(diveId);
});
