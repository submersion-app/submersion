import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/domain/services/source_alignment_check.dart';

export 'package:submersion/features/dive_log/domain/services/source_alignment_check.dart';

/// Checks and changes where a consolidated dive's secondary computers sit in
/// time (#2894).
///
/// Consolidation places a secondary by its entry time unless its depth fit
/// clearly disagrees, but dives consolidated before that, and dives a fit
/// could not settle, keep whatever offset they got. This moves one source's
/// recording to a new offset after the fact.
class SourceTimeAlignmentService {
  SourceTimeAlignmentService({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database),
      _profileSeries = ProfileSeriesRepository(database: database),
      _tankSeries = TankPressureSeriesRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;
  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;

  /// One check per secondary source of [diveId] whose depth trace and the
  /// primary's can both be read; empty for a single-source dive.
  Future<List<SourceAlignmentCheck>> check(String diveId) async {
    final sources = await _sources(diveId);
    final primary = sources.where((s) => s.isPrimary).firstOrNull;
    if (primary == null || sources.length < 2) return const [];
    final series = await _profileSeries.getSeriesForDive(diveId);
    final primaryTrace = _primaryTrace(series, primary);
    if (primaryTrace == null) return const [];

    final checks = <SourceAlignmentCheck>[];
    for (final source in sources) {
      if (source.isPrimary) continue;
      final own = _longest(series.where((s) => _owns(source, s)));
      if (own == null) continue;
      final stored = source.timeOffsetSeconds ?? 0;
      // Back on the source's own timeline, so the fit is the whole offset.
      final sourceTrace = [
        for (final p in own.samples)
          DiveProfilePoint(timestamp: p.timestamp - stored, depth: p.depth),
      ];
      checks.add(
        SourceAlignmentCheck(
          sourceId: source.id,
          storedOffsetSeconds: stored,
          fit: const ProfileAligner().align(primaryTrace, sourceTrace),
          primaryTrace: primaryTrace,
          sourceTrace: sourceTrace,
        ),
      );
    }
    return checks;
  }

  /// Moves secondary source [sourceId] of [diveId] so it sits
  /// [offsetSeconds] from the primary: its depth and pressure series, its
  /// events and gas switches all shift by the change, and the source records
  /// the new offset so a re-parse reapplies it (#1177).
  ///
  /// Returns the offset the source had before, for an undo. Throws
  /// [ArgumentError] for the primary source (every offset is relative to it)
  /// or a source that is not this dive's.
  Future<int> setOffset({
    required String diveId,
    required String sourceId,
    required int offsetSeconds,
  }) async {
    final sources = await _sources(diveId);
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) {
      throw ArgumentError('Dive $diveId has no data source $sourceId');
    }
    if (source.isPrimary) {
      throw ArgumentError('The primary source of dive $diveId cannot move');
    }
    final previous = source.timeOffsetSeconds ?? 0;
    final delta = offsetSeconds - previous;
    if (delta == 0) return previous;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      for (final s in await _profileSeries.getSeriesForDive(diveId)) {
        if (!_owns(source, s) || s.samples.isEmpty) continue;
        await _profileSeries.deleteByIds([s.id]);
        await _profileSeries.insertSeries(
          diveId: diveId,
          computerId: s.computerId,
          sourceId: s.sourceId,
          isPrimary: s.isPrimary,
          activatedAt: Value(s.activatedAt),
          samples: [for (final p in s.samples) p.shiftedBy(delta)],
          now: now,
        );
      }
      for (final s in await _tankSeries.getSeriesForDive(diveId)) {
        if (!_ownsPressure(source, s) || s.samples.isEmpty) continue;
        await _tankSeries.deleteByIds([s.id]);
        await _tankSeries.insertSeries(
          diveId: diveId,
          tankId: s.tankId,
          computerId: s.computerId,
          sourceId: s.sourceId,
          samples: [for (final p in s.samples) p.shiftedBy(delta)],
          now: now,
        );
      }

      // Events and gas switches name only a computer. One without a
      // computer is the diver's or could be any source's, so it stays.
      final computerId = source.computerId;
      if (computerId != null) {
        final events =
            await (_db.select(_db.diveProfileEvents)..where(
                  (t) =>
                      t.diveId.equals(diveId) & t.computerId.equals(computerId),
                ))
                .get();
        for (final e in events) {
          await (_db.update(
            _db.diveProfileEvents,
          )..where((t) => t.id.equals(e.id))).write(
            DiveProfileEventsCompanion(timestamp: Value(e.timestamp + delta)),
          );
          await _sync.markRecordPending(
            entityType: 'diveProfileEvents',
            recordId: e.id,
            localUpdatedAt: now,
          );
        }
        final switches =
            await (_db.select(_db.gasSwitches)..where(
                  (t) =>
                      t.diveId.equals(diveId) & t.computerId.equals(computerId),
                ))
                .get();
        for (final g in switches) {
          await (_db.update(
            _db.gasSwitches,
          )..where((t) => t.id.equals(g.id))).write(
            GasSwitchesCompanion(timestamp: Value(g.timestamp + delta)),
          );
          await _sync.markRecordPending(
            entityType: 'gasSwitches',
            recordId: g.id,
            localUpdatedAt: now,
          );
        }
      }

      await (_db.update(
        _db.diveDataSources,
      )..where((t) => t.id.equals(sourceId))).write(
        DiveDataSourcesCompanion(timeOffsetSeconds: Value(offsetSeconds)),
      );
      await _sync.markRecordPending(
        entityType: 'diveDataSources',
        recordId: sourceId,
        localUpdatedAt: now,
      );
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    });

    // The merged profile changed: drop the stored safety review so it
    // recomputes, as a profile edit does.
    await SafetyFindingsRepository.clearReviewForDive(_db, _sync, diveId);
    SyncEventBus.notifyLocalChange();
    return previous;
  }

  Future<List<DiveDataSourcesData>> _sources(String diveId) => (_db.select(
    _db.diveDataSources,
  )..where((t) => t.diveId.equals(diveId))).get();

  /// The ownership rule `ProfileSeriesRepository` uses: the source by id,
  /// or an unattributed series of the source's computer. A source with no
  /// computer claims only what names it, since an unattributed series
  /// without a computer is a manual entry.
  static bool _owns(DiveDataSourcesData source, domain.ProfileSeries s) =>
      s.sourceId == source.id ||
      (s.sourceId == null &&
          source.computerId != null &&
          s.computerId == source.computerId);

  static bool _ownsPressure(
    DiveDataSourcesData source,
    domain.TankPressureSeries s,
  ) =>
      s.sourceId == source.id ||
      (s.sourceId == null &&
          source.computerId != null &&
          s.computerId == source.computerId);

  /// The live trace of the primary: its own series if it has one, else the
  /// dive's primary series that no secondary owns.
  static List<DiveProfilePoint>? _primaryTrace(
    List<domain.ProfileSeries> series,
    DiveDataSourcesData primary,
  ) {
    final live = series.where((s) => s.isPrimary).toList();
    final chosen =
        _longest(live.where((s) => _owns(primary, s))) ?? _longest(live);
    if (chosen == null) return null;
    return [
      for (final p in chosen.samples)
        DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
    ];
  }

  static domain.ProfileSeries? _longest(Iterable<domain.ProfileSeries> series) {
    domain.ProfileSeries? best;
    for (final s in series) {
      if (best == null || s.samples.length > best.samples.length) best = s;
    }
    return best;
  }
}
