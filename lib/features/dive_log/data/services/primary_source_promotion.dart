import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/data_source_strand.dart';
import 'package:submersion/features/dive_log/data/services/dive_timeline_rezero.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as series;
import 'package:submersion/features/dive_log/domain/services/source_bottom_time.dart';
import 'package:submersion/features/dive_log/domain/services/source_runtime.dart';

/// When a dive's primary source leaves (Split, Remove source), promotes the
/// remaining source with the earliest creation timestamp and returns the
/// dive row's new attribution and summary from it, with `updatedAt` set.
/// The caller owns the transaction and writes the returned companion.
///
/// [remainingProfileSeries] is the dive's profile series without the ones
/// leaving with [leaving]; [leavingProfileIds] are those that leave.
Future<DivesCompanion> promoteAfterPrimaryLeaves({
  required AppDatabase db,
  required SyncRepository sync,
  required ProfileSeriesRepository profileSeries,
  required TankPressureSeriesRepository tankSeries,
  required String diveId,
  required DiveDataSourcesData leaving,
  required List<DiveDataSourcesData> sources,
  required Dive diveRow,
  required Set<String> liveEditIds,
  required Iterable<series.ProfileSeries> remainingProfileSeries,
  required Set<String> leavingProfileIds,
  required int now,
}) async {
  final promoted = sources.firstWhere((s) => s.id != leaving.id);
  await (db.update(db.diveDataSources)..where((t) => t.id.equals(promoted.id)))
      .write(const DiveDataSourcesCompanion(isPrimary: Value(true)));
  await sync.markRecordPending(
    entityType: 'diveDataSources',
    recordId: promoted.id,
    localUpdatedAt: now,
  );

  // Promote the remaining source's profile series so getDiveProfile (which
  // filters isPrimary) still returns a profile, unless primary series (e.g. a
  // user-edited profile) already remain. promoteOwnedBy matches on the
  // owning-source FK first, and only falls back to the pre-v154 computerId
  // convention for series that carry none. The old code gated the whole
  // promote on `promoted.computerId != null`, so a file-imported source
  // promoted nothing and left the remaining dive with zero is_primary series,
  // the same stranding as issue #1149.
  if (!await profileSeries.hasPrimarySeries(diveId)) {
    await profileSeries.promoteOwnedBy(
      diveId,
      sourceId: promoted.id,
      computerId: promoted.computerId,
      now: now,
    );
  }

  // The dive now starts when the promoted source did, so that moment becomes
  // the zero of everything left on its timeline. Without this the promoted
  // source's first sample would read as its offset past its own entry time.
  final promotedOffset = promoted.timeOffsetSeconds ?? 0;
  if (promotedOffset != 0) {
    await rezeroDiveTimeline(
      db: db,
      sync: sync,
      profileSeries: profileSeries,
      tankSeries: tankSeries,
      diveId: diveId,
      offset: promotedOffset,
      now: now,
    );
  }

  // The safety review grades the primary's own samples, so the stored one
  // graded the computer that just left.
  await SafetyFindingsRepository.clearReviewForDive(db, sync, diveId);

  // An edit that stayed behind describes the dive; the promoted source's row
  // describes a recording the dive is not showing (issue #3931).
  final keptEdit = liveEditIds.difference(leavingProfileIds).isNotEmpty;
  final keptDepths = keptEdit
      ? await profileSeries.liveDepthSummary(diveId)
      : null;

  final promotedTiming = snapshotSourceTiming(
    sources.where((s) => s.id != leaving.id).toList()
      ..sort(compareDataSourcesInShownOrder),
    promoted,
    diveRow,
    promotedOffset,
  );

  return DivesCompanion(
    updatedAt: Value(now),
    diveDateTime: Value(
      promotedTiming.entryMs ?? diveRow.diveDateTime + promotedOffset * 1000,
    ),
    computerId: Value(promoted.computerId),
    diveComputerModel: Value(promoted.computerModel),
    diveComputerSerial: Value(promoted.computerSerial),
    maxDepth: Value(
      keptDepths?.maxDepth ?? promoted.maxDepth ?? diveRow.maxDepth,
    ),
    avgDepth: Value(
      keptDepths?.avgDepth ?? promoted.avgDepth ?? diveRow.avgDepth,
    ),
    bottomTime: Value(
      sourceBottomTimeSeconds(
            remainingProfileSeries,
            sourceId: promoted.id,
            computerId: promoted.computerId,
            runtimeSeconds: promotedTiming.runtimeSeconds,
          ) ??
          diveRow.bottomTime,
    ),
    runtime: Value(promotedTiming.runtimeSeconds ?? diveRow.runtime),
    waterTemp: Value(promoted.waterTemp ?? diveRow.waterTemp),
    entryTime: Value(promotedTiming.entryMs),
    exitTime: Value(promotedTiming.exitMs),
    surfaceIntervalSeconds: Value(
      promoted.surfaceInterval ?? diveRow.surfaceIntervalSeconds,
    ),
    cnsEnd: Value(promoted.cns ?? diveRow.cnsEnd),
    decoAlgorithm: Value(promoted.decoAlgorithm ?? diveRow.decoAlgorithm),
    gradientFactorLow: Value(
      promoted.gradientFactorLow ?? diveRow.gradientFactorLow,
    ),
    gradientFactorHigh: Value(
      promoted.gradientFactorHigh ?? diveRow.gradientFactorHigh,
    ),
  );
}

/// The timing [row] gives a dive, among [rows]: each timestamp falls back to
/// [diveRow]'s moved [offset] seconds later, and the runtime is null when
/// neither yields one, leaving the caller to keep the dive's own alongside
/// those timestamps.
({int? entryMs, int? exitMs, int? runtimeSeconds}) snapshotSourceTiming(
  List<DiveDataSourcesData> rows,
  DiveDataSourcesData row,
  Dive diveRow,
  int offset,
) {
  int? later(int? epochMs) => epochMs == null ? null : epochMs + offset * 1000;
  final timing = dataSourceStrandTiming(rows, row);
  final entryMs = timing.entryMs ?? later(diveRow.entryTime);
  final exitMs = timing.exitMs ?? later(diveRow.exitTime);
  return (
    entryMs: entryMs,
    exitMs: exitMs,
    runtimeSeconds: sourceRuntimeSeconds(
      durationSeconds: timing.durationSeconds,
      entryTimeMs: entryMs,
      exitTimeMs: exitMs,
    ),
  );
}
