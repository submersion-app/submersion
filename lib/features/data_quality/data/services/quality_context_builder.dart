import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as series;
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
import 'package:submersion/features/data_quality/data/services/diver_data_sql.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

class QualityContextBuilder {
  QualityContextBuilder({
    DiveRepository? diveRepository,
    DiverSettingsRepository? settingsRepository,
    TransmitterRepository? transmitterRepository,
  }) : _diveRepo = diveRepository ?? DiveRepository(),
       _settingsRepo = settingsRepository ?? DiverSettingsRepository(),
       _transmitterRepo = transmitterRepository ?? TransmitterRepository();

  final DiveRepository _diveRepo;
  final DiverSettingsRepository _settingsRepo;
  final TransmitterRepository _transmitterRepo;

  /// Registered transmitter serials per diver id, resolved once per
  /// [buildAll] batch. '' stands for the null diver, like the ppO2 cache.
  final Map<String, Set<String>> _knownSerialsByDiver = {};
  final _profileSeries = ProfileSeriesRepository();
  final _tankSeries = TankPressureSeriesRepository();
  AppDatabase get _db => DatabaseService.instance.database;

  /// ppO2 ceiling per diver id, resolved once per [buildAll] batch. The key
  /// '' stands for the implicit default diver (a null diver_id).
  final Map<String, double> _ppO2MaxByDiver = {};

  Future<List<DiveQualityContext>> buildAll(
    List<String> diveIds, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    _ppO2MaxByDiver.clear();
    _knownSerialsByDiver.clear();
    final dives = await _diveRepo.getDivesByIds(diveIds);
    final out = <DiveQualityContext>[];
    for (final dive in dives) {
      out.add(await _build(dive, effectiveNow));
    }
    return out;
  }

  /// The diver's configured maximum ppO2, or the default ceiling when the
  /// dive has no diver or no stored settings. Cached for the batch.
  Future<double> _ppO2Max(String? diverId) async {
    final key = diverId ?? '';
    final cached = _ppO2MaxByDiver[key];
    if (cached != null) return cached;
    var value = QualityThresholds.ppO2WarnBar;
    if (diverId != null) {
      final settings = await _settingsRepo.getSettingsForDiver(diverId);
      if (settings != null) value = settings.ppO2MaxDeco;
    }
    _ppO2MaxByDiver[key] = value;
    return value;
  }

  Future<Set<String>> _knownSerials(String? diverId) async {
    final key = diverId ?? '';
    final cached = _knownSerialsByDiver[key];
    if (cached != null) return cached;
    Set<String> value;
    try {
      value = Transmitter.knownSerials(
        await _transmitterRepo.getForDiver(diverId),
      );
    } catch (_) {
      value = const {};
    }
    _knownSerialsByDiver[key] = value;
    return value;
  }

  Future<DiveQualityContext> _build(domain.Dive dive, DateTime now) async {
    final primarySeries = await _profileSeries.getSeriesForDive(
      dive.id,
      primaryOnly: true,
    );
    // Summed from the stored summaries, not counted off the merged list
    // below, so it agrees with the neighbor query's SUM over the same column.
    final primarySampleCount = primarySeries.isEmpty
        ? null
        : primarySeries.fold<int>(0, (n, s) => n + s.summary.sampleCount);
    final samples = <QualitySample>[
      for (final p in mergeSeriesPointsCollapsingDuplicates(primarySeries))
        if (p.depth.isFinite &&
            (p.temperature == null || p.temperature!.isFinite))
          QualitySample(t: p.timestamp, depth: p.depth, temp: p.temperature),
    ];

    final pressures = <String, List<QualityPressureSample>>{};
    final tankSeries = await _tankSeries.getSeriesForDive(dive.id);
    final byTank = <String, List<series.TankPressureSeries>>{};
    for (final s in tankSeries) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    for (final entry in byTank.entries) {
      for (final p in mergeTankSeriesPoints(entry.value)) {
        if (!p.pressure.isFinite) continue;
        pressures
            .putIfAbsent(entry.key, () => [])
            .add(QualityPressureSample(t: p.timestamp, bar: p.pressure));
      }
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
    final carriesDiverData = await _carriesDiverData(dive.id);

    return DiveQualityContext(
      dive: dive,
      now: now,
      sources: sources,
      primarySamples: samples,
      primarySampleCount: primarySampleCount,
      carriesDiverData: carriesDiverData,
      tanks: dive.tanks,
      pressuresByTankId: pressures,
      gasSwitches: switches,
      neighbors: neighbors,
      ppO2MaxBar: await _ppO2Max(dive.diverId),
      knownTransmitterSerials: await _knownSerials(dive.diverId),
    );
  }

  /// [DiveQualityContext.carriesDiverData] for one dive. Read through the same
  /// fragment the neighbor query uses so a duplicate pair's two sides are
  /// measured identically; null when the row is gone, which leaves the
  /// delete-duplicate repair withheld rather than offered on a guess (#1720).
  Future<bool?> _carriesDiverData(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT ($kDiverDataExistsSql) AS carries_diver_data '
          'FROM dives WHERE id = ?1',
          variables: [Variable.withString(diveId)],
          readsFrom: diverDataTables(_db),
        )
        .get();
    if (rows.isEmpty) return null;
    return (rows.single.read<int?>('carries_diver_data') ?? 0) != 0;
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
          '(SELECT s.first_depth FROM dive_profile_series s '
          'WHERE s.dive_id = dives.id AND s.is_primary = 1 '
          'ORDER BY s.start_timestamp ASC, s.id ASC LIMIT 1) AS first_depth, '
          '(SELECT s.last_depth FROM dive_profile_series s '
          'WHERE s.dive_id = dives.id AND s.is_primary = 1 '
          // start_timestamp before id: series order is (start_timestamp,
          // id), so on an end-timestamp tie (the sync union of one profile
          // from two devices) the merged read's last sample comes from the
          // LATER-starting series, whatever its id sorts as. Ordering by id
          // alone picked the other one and reported a last depth no other
          // reader agrees with.
          'ORDER BY s.end_timestamp DESC, s.start_timestamp DESC, '
          's.id DESC LIMIT 1) AS last_depth, '
          // NULL (not 0) when the neighbor has no primary series, so an
          // unknown recording never reads as an empty one.
          '(SELECT SUM(s.sample_count) FROM dive_profile_series s '
          'WHERE s.dive_id = dives.id AND s.is_primary = 1) AS sample_count, '
          // Projected here rather than looked up per neighbor: the scan
          // resolves this window for every dive in the library, and a second
          // round trip per neighbor would be an N+1 (#1720).
          '($kDiverDataExistsSql) AS carries_diver_data '
          'FROM dives WHERE id != ?1 AND diver_id IS ?2 '
          'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4 '
          'ORDER BY COALESCE(entry_time, dive_date_time) ASC',
          variables: [
            Variable.withString(dive.id),
            Variable(dive.diverId),
            Variable.withInt(entry.millisecondsSinceEpoch - windowMs),
            Variable.withInt(exit.millisecondsSinceEpoch + windowMs),
          ],
          readsFrom: {...diverDataTables(_db), _db.diveProfileSeries},
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
          sampleCount: row.read<int?>('sample_count'),
          carriesDiverData: (row.read<int?>('carries_diver_data') ?? 0) != 0,
        ),
      );
    }
    return out;
  }

  double? _finiteDepth(double? d) => (d != null && d.isFinite) ? d : null;
}
