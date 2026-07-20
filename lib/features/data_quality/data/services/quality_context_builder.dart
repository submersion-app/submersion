import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';

class QualityContextBuilder {
  QualityContextBuilder({DiveRepository? diveRepository})
    : _diveRepo = diveRepository ?? DiveRepository();

  final DiveRepository _diveRepo;
  AppDatabase get _db => DatabaseService.instance.database;

  Future<List<DiveQualityContext>> buildAll(
    List<String> diveIds, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final dives = await _diveRepo.getDivesByIds(diveIds);
    final out = <DiveQualityContext>[];
    for (final dive in dives) {
      out.add(await _build(dive, effectiveNow));
    }
    return out;
  }

  Future<DiveQualityContext> _build(domain.Dive dive, DateTime now) async {
    final profileRows =
        await (_db.select(_db.diveProfiles)
              ..where(
                (t) => t.diveId.equals(dive.id) & t.isPrimary.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final samples = <QualitySample>[
      for (final r in profileRows)
        if (r.depth.isFinite &&
            (r.temperature == null || r.temperature!.isFinite))
          QualitySample(t: r.timestamp, depth: r.depth, temp: r.temperature),
    ];

    final pressureRows =
        await (_db.select(_db.tankPressureProfiles)
              ..where((t) => t.diveId.equals(dive.id))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final pressures = <String, List<QualityPressureSample>>{};
    for (final r in pressureRows) {
      if (!r.pressure.isFinite) continue;
      pressures
          .putIfAbsent(r.tankId, () => [])
          .add(QualityPressureSample(t: r.timestamp, bar: r.pressure));
    }

    final switchRows =
        await (_db.select(_db.gasSwitches)
              ..where((t) => t.diveId.equals(dive.id))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    final switches = [
      for (final r in switchRows)
        GasSwitch(
          id: r.id,
          diveId: r.diveId,
          timestamp: r.timestamp,
          tankId: r.tankId,
          depth: r.depth,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        ),
    ];

    final sources = await _diveRepo.getDataSources(dive.id);
    final neighbors = await _neighbors(dive);

    return DiveQualityContext(
      dive: dive,
      now: now,
      sources: sources,
      primarySamples: samples,
      tanks: dive.tanks,
      pressuresByTankId: pressures,
      gasSwitches: switches,
      neighbors: neighbors,
    );
  }

  Future<List<QualityNeighbor>> _neighbors(domain.Dive dive) async {
    final entry = dive.effectiveEntryTime;
    final exit = entry.add(dive.effectiveRuntime ?? Duration.zero);
    final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
    // `IS` (not `=`) is intentional: an unassigned dive (diver_id NULL) belongs
    // to the implicit default diver, and `getAllDives(null)`/`DiveMatcher` treat
    // all such dives as one scope. `IS` matches same-id and both-NULL, but never
    // NULL-vs-non-NULL, so a null-diver dive is never paired across into a
    // specific diver's dives. Do not "fix" this to `=`: that drops neighbor
    // detection for the common single-diver (all-NULL) library.
    // Project each neighbor's first/last primary-sample depth via correlated
    // subqueries so the whole window resolves in one query instead of two
    // extra point lookups per neighbor (an N+1 during full-library scans).
    final rows = await _db
        .customSelect(
          'SELECT id, entry_time, dive_date_time, exit_time, max_depth, '
          'runtime, bottom_time, dive_computer_serial, '
          '(SELECT depth FROM dive_profiles p WHERE p.dive_id = dives.id '
          'AND p.is_primary = 1 ORDER BY p.timestamp ASC LIMIT 1) '
          'AS first_depth, '
          '(SELECT depth FROM dive_profiles p WHERE p.dive_id = dives.id '
          'AND p.is_primary = 1 ORDER BY p.timestamp DESC LIMIT 1) '
          'AS last_depth '
          'FROM dives WHERE id != ?1 AND diver_id IS ?2 '
          'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4 '
          'ORDER BY COALESCE(entry_time, dive_date_time) ASC',
          variables: [
            Variable.withString(dive.id),
            Variable(dive.diverId),
            Variable.withInt(entry.millisecondsSinceEpoch - windowMs),
            Variable.withInt(exit.millisecondsSinceEpoch + windowMs),
          ],
          readsFrom: {_db.dives, _db.diveProfiles},
        )
        .get();
    final out = <QualityNeighbor>[];
    for (final row in rows) {
      final entryMs =
          row.read<int?>('entry_time') ?? row.read<int?>('dive_date_time');
      if (entryMs == null) continue;
      final durationSeconds =
          row.read<int?>('runtime') ?? row.read<int?>('bottom_time');
      final exitMs =
          row.read<int?>('exit_time') ??
          (durationSeconds != null ? entryMs + durationSeconds * 1000 : null);
      final id = row.read<String>('id');
      out.add(
        QualityNeighbor(
          id: id,
          // Dive times are stored/read as UTC epoch millis; reconstruct with
          // isUtc so calendar fields and wall-clock dates match the dive repo.
          entryTime: DateTime.fromMillisecondsSinceEpoch(entryMs, isUtc: true),
          exitTime: exitMs != null
              ? DateTime.fromMillisecondsSinceEpoch(exitMs, isUtc: true)
              : null,
          maxDepth: row.read<double?>('max_depth'),
          durationSeconds: durationSeconds,
          computerSerial: row.read<String?>('dive_computer_serial'),
          firstSampleDepth: _finiteDepth(row.read<double?>('first_depth')),
          lastSampleDepth: _finiteDepth(row.read<double?>('last_depth')),
        ),
      );
    }
    return out;
  }

  double? _finiteDepth(double? d) => (d != null && d.isFinite) ? d : null;
}
