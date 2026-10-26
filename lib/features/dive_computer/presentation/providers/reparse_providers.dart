import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

/// Provider for the [ReparseService] singleton.
///
/// Watches the surfacing-pressure and unused-gas settings so a reparse run
/// after the diver flips one applies the current preference (issues #1092 and
/// #3668).
final reparseServiceProvider = Provider<ReparseService>((ref) {
  final db = DatabaseService.instance.database;
  return ReparseService(
    db: db,
    trimTankPressureAtSurfacing: ref.watch(
      settingsProvider.select((s) => s.trimTankPressureAtSurfacing),
    ),
    omitUnusedOcGases: ref.watch(
      settingsProvider.select((s) => s.omitUnusedOcGases),
    ),
    cleanupTankPresetLoader: () => loadDefaultTankPresetForCleanup(ref),
    transmitterMatcherLoader: () => loadTransmitterMatcher(ref),
  );
});

/// Provides raw data counts for all dive computer sources matching [computerId].
///
/// Returns a record with [withRawData] and [withoutRawData] counts. Refreshed
/// whenever a data source row changes, so a discard made here or synced from
/// another device (issue #1376) does not leave a stale count behind.
final rawDataCountProvider =
    FutureProvider.family<({int withRawData, int withoutRawData}), String>((
      ref,
      computerId,
    ) {
      final service = ref.watch(reparseServiceProvider);
      ref.invalidateSelfWhen(
        service.db.tableUpdates(
          TableUpdateQuery.onTable(service.db.diveDataSources),
        ),
      );
      return service.getRawDataCounts(computerId);
    });

/// Returns whether any [DiveDataSources] row for [diveId] has raw data stored.
final diveHasRawDataProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) {
  final service = ref.watch(reparseServiceProvider);
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  return service.hasRawData(diveId);
});
