import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/source_clock_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/services/series_source_owner.dart';

/// The rows [SourceTimelineShifter.shift] moved, so its undo moves exactly
/// those back however ownership reads by then.
class SourceTimelineShift {
  const SourceTimelineShift({
    required this.diveId,
    required this.sourceId,
    required this.seconds,
    required this.profileSeriesIds,
    required this.tankSeriesIds,
    required this.eventIds,
    required this.gasSwitchIds,
    required this.window,
  });

  final String diveId;
  final String sourceId;
  final int seconds;
  final List<String> profileSeriesIds;
  final List<String> tankSeriesIds;
  final List<String> eventIds;
  final List<String> gasSwitchIds;

  /// The source's entry and exit times before the shift.
  final List<SourceTimesSnapshot> window;
}

/// Moves one source of a dive along the primary's timeline: everything a
/// consolidation re-based by that source's offset (its profile and tank
/// pressure series, its computer's events and gas switches), the offset it
/// recorded, and its own entry and exit times, which read the same wrong
/// clock (#4296). The logbook and every other source stay where they are.
class SourceTimelineShifter {
  SourceTimelineShifter({
    AppDatabase? database,
    DiveRepository? diveRepository,
    ProfileSeriesRepository? profileSeries,
    TankPressureSeriesRepository? tankSeries,
    SourceClockRepository? sourceClocks,
  }) : _database = database,
       _diveRepo = diveRepository ?? DiveRepository(),
       _profileSeries = profileSeries ?? ProfileSeriesRepository(),
       _tankSeries = tankSeries ?? TankPressureSeriesRepository(),
       _sourceClocks =
           sourceClocks ?? SourceClockRepository(database: database),
       _sync = SyncRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final DiveRepository _diveRepo;
  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;
  final SourceClockRepository _sourceClocks;
  final SyncRepository _sync;

  /// Moves [sourceId]'s rows on [diveId] by [seconds]. Null when the dive no
  /// longer has that source or there is nothing to move.
  Future<SourceTimelineShift?> shift({
    required String diveId,
    required String sourceId,
    required int seconds,
  }) async {
    if (seconds == 0) return null;
    final sources = await _diveRepo.getDataSources(diveId);
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return null;
    bool owns({String? sourceId, String? computerId}) =>
        seriesSourceOwner(
          sourceId: sourceId,
          computerId: computerId,
          sources: sources,
        ) ==
        source.id;
    // Events and switches carry no source, only a computer, so they move
    // only when that computer names this source alone.
    final computerId = source.computerId;
    final ownsComputer = computerId != null && owns(computerId: computerId);

    final profile = [
      for (final s in await _profileSeries.getSeriesForDive(diveId))
        if (owns(sourceId: s.sourceId, computerId: s.computerId)) s.id,
    ];
    final tanks = [
      for (final s in await _tankSeries.getSeriesForDive(diveId))
        if (owns(sourceId: s.sourceId, computerId: s.computerId)) s.id,
    ];
    final events = !ownsComputer
        ? const <String>[]
        : [
            for (final row
                in await (_db.select(_db.diveProfileEvents)..where(
                      (t) =>
                          t.diveId.equals(diveId) &
                          t.computerId.equals(computerId) &
                          t.source.equals(EventSource.user.name).not(),
                    ))
                    .get())
              row.id,
          ];
    final switches = !ownsComputer
        ? const <String>[]
        : [
            for (final row
                in await (_db.select(_db.gasSwitches)..where(
                      (t) =>
                          t.diveId.equals(diveId) &
                          t.computerId.equals(computerId),
                    ))
                    .get())
              row.id,
          ];
    final record = SourceTimelineShift(
      diveId: diveId,
      sourceId: sourceId,
      seconds: seconds,
      profileSeriesIds: profile,
      tankSeriesIds: tanks,
      eventIds: events,
      gasSwitchIds: switches,
      window: await _sourceClocks.snapshot([sourceId]),
    );
    await _db.transaction(() async {
      await _move(record, seconds);
      await _sourceClocks.shift(record.window, Duration(seconds: seconds));
    });
    return record;
  }

  /// Puts back what [record] moved.
  Future<void> undo(SourceTimelineShift record) => _db.transaction(() async {
    await _move(record, -record.seconds);
    await _sourceClocks.restore(record.window);
  });

  Future<void> _move(SourceTimelineShift record, int seconds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final profileIds = record.profileSeriesIds.toSet();
    await _profileSeries.shiftSamples(
      [
        for (final s in await _profileSeries.getSeriesForDive(record.diveId))
          if (profileIds.contains(s.id)) s,
      ],
      seconds,
      now: now,
    );
    final tankIds = record.tankSeriesIds.toSet();
    await _tankSeries.shiftSamples(
      [
        for (final s in await _tankSeries.getSeriesForDive(record.diveId))
          if (tankIds.contains(s.id)) s,
      ],
      seconds,
      now: now,
    );
    for (final id in record.eventIds) {
      await _db.customUpdate(
        'UPDATE dive_profile_events SET timestamp = timestamp + ? '
        'WHERE id = ?',
        variables: [Variable.withInt(seconds), Variable.withString(id)],
        updates: {_db.diveProfileEvents},
      );
      await _sync.markRecordPending(
        entityType: 'diveProfileEvents',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    for (final id in record.gasSwitchIds) {
      await _db.customUpdate(
        'UPDATE gas_switches SET timestamp = timestamp + ? WHERE id = ?',
        variables: [Variable.withInt(seconds), Variable.withString(id)],
        updates: {_db.gasSwitches},
      );
      await _sync.markRecordPending(
        entityType: 'gasSwitches',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await _db.customUpdate(
      'UPDATE dive_data_sources '
      'SET time_offset_seconds = COALESCE(time_offset_seconds, 0) + ? '
      'WHERE id = ?',
      variables: [
        Variable.withInt(seconds),
        Variable.withString(record.sourceId),
      ],
      updates: {_db.diveDataSources},
    );
    await _sync.markRecordPending(
      entityType: 'diveDataSources',
      recordId: record.sourceId,
      localUpdatedAt: now,
    );
  }
}
