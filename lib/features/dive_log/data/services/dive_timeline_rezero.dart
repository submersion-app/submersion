import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';

/// Makes the moment [offset] seconds along [diveId]'s timeline its new zero.
///
/// Everything on the timeline moves back by [offset] together, so the
/// remaining strands stay aligned with one another and each of their recorded
/// offsets stays true, and a photo stays at its moment. Run after any departing
/// source's rows are gone, inside the caller's transaction.
Future<void> rezeroDiveTimeline({
  required AppDatabase db,
  required SyncRepository sync,
  required ProfileSeriesRepository profileSeries,
  required TankPressureSeriesRepository tankSeries,
  required String diveId,
  required int offset,
  required int now,
}) async {
  await profileSeries.shiftSamples(
    await profileSeries.getSeriesForDive(diveId),
    -offset,
    now: now,
  );
  await tankSeries.shiftSamples(
    await tankSeries.getSeriesForDive(diveId),
    -offset,
    now: now,
  );
  final events = await (db.select(
    db.diveProfileEvents,
  )..where((t) => t.diveId.equals(diveId))).get();
  for (final row in events) {
    await (db.update(
      db.diveProfileEvents,
    )..where((t) => t.id.equals(row.id))).write(
      DiveProfileEventsCompanion(timestamp: Value(row.timestamp - offset)),
    );
    await sync.markRecordPending(
      entityType: 'diveProfileEvents',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  final switches = await (db.select(
    db.gasSwitches,
  )..where((t) => t.diveId.equals(diveId))).get();
  for (final row in switches) {
    await (db.update(db.gasSwitches)..where((t) => t.id.equals(row.id))).write(
      GasSwitchesCompanion(timestamp: Value(row.timestamp - offset)),
    );
    await sync.markRecordPending(
      entityType: 'gasSwitches',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  final pinned =
      await (db.select(db.media)..where(
            (t) => t.diveId.equals(diveId) & t.manualElapsedSeconds.isNotNull(),
          ))
          .get();
  for (final row in pinned) {
    await (db.update(db.media)..where((t) => t.id.equals(row.id))).write(
      MediaCompanion(
        manualElapsedSeconds: Value(row.manualElapsedSeconds! - offset),
        updatedAt: Value(now),
      ),
    );
    await sync.markRecordPending(
      entityType: 'media',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  // A shift, not a job for the enricher: nothing recomputes a row that
  // already exists until the diver next pins or opens that photo.
  final placed =
      await (db.select(db.mediaEnrichment)..where(
            (t) => t.diveId.equals(diveId) & t.elapsedSeconds.isNotNull(),
          ))
          .get();
  for (final row in placed) {
    await (db.update(
      db.mediaEnrichment,
    )..where((t) => t.id.equals(row.id))).write(
      MediaEnrichmentCompanion(
        elapsedSeconds: Value(row.elapsedSeconds! - offset),
      ),
    );
    await sync.markRecordPending(
      entityType: 'mediaEnrichment',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  final remaining = await (db.select(
    db.diveDataSources,
  )..where((t) => t.diveId.equals(diveId))).get();
  for (final source in remaining) {
    await (db.update(
      db.diveDataSources,
    )..where((t) => t.id.equals(source.id))).write(
      DiveDataSourcesCompanion(
        timeOffsetSeconds: Value((source.timeOffsetSeconds ?? 0) - offset),
      ),
    );
    await sync.markRecordPending(
      entityType: 'diveDataSources',
      recordId: source.id,
      localUpdatedAt: now,
    );
  }
}
