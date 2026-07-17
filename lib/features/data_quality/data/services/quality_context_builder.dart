import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../dive_log/data/repositories/dive_repository_impl.dart';
import '../../../dive_log/domain/entities/dive.dart' as domain;
import '../../../dive_log/domain/entities/gas_switch.dart';
import '../../domain/entities/dive_quality_context.dart';
import '../../domain/quality_thresholds.dart';

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
    final rows = await _db
        .customSelect(
          'SELECT id, entry_time, dive_date_time, exit_time, max_depth, '
          'runtime, bottom_time, dive_computer_serial '
          'FROM dives WHERE id != ?1 AND diver_id IS ?2 '
          'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4 '
          'ORDER BY COALESCE(entry_time, dive_date_time) ASC',
          variables: [
            Variable.withString(dive.id),
            Variable(dive.diverId),
            Variable.withInt(entry.millisecondsSinceEpoch - windowMs),
            Variable.withInt(exit.millisecondsSinceEpoch + windowMs),
          ],
          readsFrom: {_db.dives},
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
          entryTime: DateTime.fromMillisecondsSinceEpoch(entryMs),
          exitTime: exitMs != null
              ? DateTime.fromMillisecondsSinceEpoch(exitMs)
              : null,
          maxDepth: row.read<double?>('max_depth'),
          durationSeconds: durationSeconds,
          computerSerial: row.read<String?>('dive_computer_serial'),
          firstSampleDepth: await _edgeDepth(id, first: true),
          lastSampleDepth: await _edgeDepth(id, first: false),
        ),
      );
    }
    return out;
  }

  Future<double?> _edgeDepth(String diveId, {required bool first}) async {
    final q = _db.select(_db.diveProfiles)
      ..where((t) => t.diveId.equals(diveId) & t.isPrimary.equals(true))
      ..orderBy([
        (t) => first
            ? OrderingTerm.asc(t.timestamp)
            : OrderingTerm.desc(t.timestamp),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    final d = row?.depth;
    return (d != null && d.isFinite) ? d : null;
  }
}
