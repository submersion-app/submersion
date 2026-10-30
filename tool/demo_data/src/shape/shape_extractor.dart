import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import 'dive_shape.dart';

/// Reads dive shapes out of dives the app's own importers produced.
///
/// Every source format is imported into a scratch database first, so this
/// reads one uniform model whatever the dive came from.
class ShapeExtractor {
  /// The shape of [dive], with [pressures] keyed by the dive's tank ids.
  DiveShape fromDive(
    domain.Dive dive,
    Map<String, List<domain.TankPressurePoint>> pressures, {
    int computerCount = 1,
  }) {
    final samples = [
      for (final p in dive.profile)
        ShapeSample(
          t: p.timestamp,
          depth: p.depth,
          temp: p.temperature,
          heartRate: p.heartRate,
          ppO2: p.ppO2,
          setpoint: p.setpoint,
          cells: _cells(p),
        ),
    ];
    final tanks = [...dive.tanks]..sort((a, b) => a.order.compareTo(b.order));
    final shapeTanks = [
      for (final t in tanks)
        ShapeTank(
          o2: t.gasMix.o2,
          he: t.gasMix.he,
          role: t.role.name,
          volumeL: t.volume,
          startBar: t.startPressure,
          endBar: t.endPressure,
          pressures: [
            for (final p
                in pressures[t.id] ?? const <domain.TankPressurePoint>[])
              (p.timestamp, p.pressure),
          ]..sort((a, b) => a.$1.compareTo(b.$1)),
        ),
    ];
    return DiveShape(
      id: shapeId(samples),
      kinds: _classify(dive.diveMode, samples, shapeTanks, computerCount),
      diveMode: dive.diveMode.name,
      sampleIntervalSec: _interval(samples),
      samples: samples,
      tanks: shapeTanks,
      computerCount: computerCount,
    );
  }

  /// Every dive with a profile in the database [DatabaseService] has open.
  Future<List<DiveShape>> fromDatabase() async {
    final db = DatabaseService.instance.database;
    final rows = await db
        .customSelect(
          'SELECT d.id AS id, COUNT(s.id) AS sources FROM dives d '
          'LEFT JOIN dive_data_sources s ON s.dive_id = d.id GROUP BY d.id',
        )
        .get();
    final dives = DiveRepository();
    final tanks = TankPressureRepository();
    final shapes = <DiveShape>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      final dive = (await dives.getDivesByIds([id])).firstOrNull;
      if (dive == null || dive.profile.length < 10) continue;
      shapes.add(
        fromDive(
          dive,
          await tanks.getTankPressuresForDive(id),
          computerCount: row.read<int>('sources').clamp(1, 9),
        ),
      );
    }
    return shapes;
  }

  /// A hash of the depth curve rounded to 0.5 m at 10 s steps: the same dive
  /// exported in two formats gets the same id.
  static String shapeId(List<ShapeSample> samples) {
    final buffer = StringBuffer();
    var next = 0;
    for (final s in samples) {
      if (s.t < next) continue;
      buffer
        ..write((s.depth * 2).round())
        ..write(',');
      next = s.t + 10;
    }
    return sha256
        .convert(utf8.encode(buffer.toString()))
        .toString()
        .substring(0, 16);
  }

  static List<double>? _cells(domain.DiveProfilePoint p) {
    final cells = [
      p.o2Sensor1,
      p.o2Sensor2,
      p.o2Sensor3,
      p.o2Sensor4,
      p.o2Sensor5,
      p.o2Sensor6,
    ].whereType<double>().toList();
    return cells.isEmpty ? null : cells;
  }

  static int _interval(List<ShapeSample> samples) {
    if (samples.length < 2) return 1;
    final gaps = [
      for (var i = 1; i < samples.length; i++) samples[i].t - samples[i - 1].t,
    ]..sort();
    return gaps[gaps.length ~/ 2].clamp(1, 60);
  }

  static Set<ShapeKind> _classify(
    DiveMode mode,
    List<ShapeSample> samples,
    List<ShapeTank> tanks,
    int computerCount,
  ) {
    final maxDepth = samples.fold<double>(
      0,
      (m, s) => s.depth > m ? s.depth : m,
    );
    final mixes = {for (final t in tanks) (t.o2.round(), t.he.round())};
    return {
      if (mode == DiveMode.ccr) ShapeKind.ccr,
      if (mode == DiveMode.scr) ShapeKind.scr,
      if (mode == DiveMode.oc && maxDepth >= 40) ShapeKind.deepOpenCircuit,
      if (mode == DiveMode.oc && maxDepth < 40 && mixes.length <= 1)
        ShapeKind.recreational,
      if (mixes.length >= 2) ShapeKind.multiGasDeco,
      if (tanks.any((t) => t.he > 0)) ShapeKind.trimix,
      if (computerCount > 1) ShapeKind.multiComputer,
      if (samples.any((s) => s.heartRate != null)) ShapeKind.heartRate,
      if (tanks.any((t) => t.pressures.length >= 5)) ShapeKind.tankPressure,
    };
  }
}
