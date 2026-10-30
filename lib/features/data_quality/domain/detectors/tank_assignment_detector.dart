import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/profile/surfacing_pressure.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

class TankAssignmentDetector extends QualityDetector {
  const TankAssignmentDetector();

  @override
  String get id => 'tank_assignment';
  @override
  int get version => 3;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.tanks.length < 2) return const [];
    final out = <QualityFinding>[];

    // Double-assigned transmitter: the same cylinder on the dive twice.
    //
    // Two tanks that carry the same transmitter serial are the same
    // cylinder by definition (the usual cause: two computers paired to one
    // transmitter, consolidated before serials were stored). Two tanks with
    // different serials are two cylinders however alike their curves, so
    // the series heuristic is skipped for them. Without serials on both
    // sides, matching pressure series are the evidence.
    final tanksById = {for (final t in ctx.tanks) t.id: t};
    final tankIds = tanksById.keys.toList()..sort();
    for (var i = 0; i < tankIds.length; i++) {
      for (var j = i + 1; j < tankIds.length; j++) {
        final serialA = _serial(tanksById[tankIds[i]]!);
        final serialB = _serial(tanksById[tankIds[j]]!);
        final sameTransmitter = serialA != null && serialA == serialB;
        if (serialA != null && serialB != null && !sameTransmitter) continue;

        final agreement = _seriesAgreement(
          ctx.pressuresByTankId[tankIds[i]] ?? const [],
          ctx.pressuresByTankId[tankIds[j]] ?? const [],
        );
        final twinSeries =
            agreement != null &&
            agreement.samples >= QualityThresholds.twinSeriesMinSamples &&
            agreement.meanDiffBar < QualityThresholds.twinSeriesMeanDiffBar;
        if (!sameTransmitter && !twinSeries) continue;

        out.add(
          make(
            ctx,
            discriminator: 'twin:${tankIds[i]}|${tankIds[j]}',
            severity: QualitySeverity.warning,
            params: {
              'tankIdA': tankIds[i],
              'tankIdB': tankIds[j],
              'meanDiffBar': agreement?.meanDiffBar ?? 0.0,
              'sameTransmitter': sameTransmitter,
            },
          ),
        );
      }
    }

    // Consumption attributed to a tank the switch timeline says was idle.
    if (ctx.gasSwitches.isNotEmpty) {
      final ordered = [...ctx.tanks]
        ..sort((a, b) => a.order.compareTo(b.order));
      String activeAt(int t) {
        var id = ordered.first.id;
        for (final sw in ctx.gasSwitches) {
          if (sw.timestamp <= t) {
            id = sw.tankId;
          } else {
            break;
          }
        }
        return id;
      }

      for (final tank in ctx.tanks) {
        // A loop cylinder is not on the open-circuit timeline; see below.
        if (isLoopTankRole(tank.role.name)) continue;
        final series = ctx.pressuresByTankId[tank.id] ?? const [];
        if (series.length < 2) continue;
        var total = 0.0;
        var inactive = 0.0;
        for (var i = 1; i < series.length; i++) {
          final d = series[i - 1].bar - series[i].bar;
          if (d <= 0) continue;
          total += d;
          if (activeAt(series[i].t) != tank.id) inactive += d;
        }
        if (total > QualityThresholds.wrongTankMinTotalDropBar &&
            inactive / total >
                QualityThresholds.wrongTankInactiveDropFraction) {
          out.add(
            make(
              ctx,
              discriminator: 'inactive:${tank.id}',
              computerId: tank.computerId,
              severity: QualitySeverity.warning,
              params: {
                'tankId': tank.id,
                'tankOrder': tank.order,
                'inactiveDropBar': inactive,
                'totalDropBar': total,
              },
            ),
          );
        }
      }
      out.addAll(_loopTankFindings(ctx));
    }
    return out;
  }

  /// Loop cylinders (diluent, O2 supply) that drained like a bailout (issue
  /// #3652). Both drain whenever the diver is on the loop, and no computer
  /// logs that as a gas switch, so the one-active-tank timeline above would
  /// call an O2 supply's whole drop idle. A loop cylinder is idle only on
  /// open circuit, and is judged there by drain rate rather than by share:
  /// a constant-mass-flow O2 supply bleeds at one rate throughout. Judged by
  /// role alone, so a rebreather dive logged in the wrong mode is covered.
  List<QualityFinding> _loopTankFindings(DiveQualityContext ctx) {
    final candidates = [
      for (final t in ctx.tanks)
        if (isLoopTankRole(t.role.name) &&
            !_leftToRoleCheck(ctx, t) &&
            (_ownSeries(ctx, t)?.length ?? 0) >= 2)
          t,
    ];
    // Most dives in a library scan are open circuit: skip the profile walk.
    if (candidates.isEmpty) return const [];

    final roleById = {for (final t in ctx.tanks) t.id: t.role};
    final inWaterEnd = lastTimeBelowSurfaceThreshold(
      ctx.primarySamples.map((s) => (t: s.t, depth: s.depth)),
    );
    final out = <QualityFinding>[];
    for (final tank in candidates) {
      final series = _ownSeries(ctx, tank)!;
      // Only this cylinder's own computer's switches describe what was
      // breathed from it; a second computer logs its own switches, and the
      // merged series can be that computer's reading.
      final evidence = bailoutEvidence<String>(
        switches: [
          for (final sw in ctx.gasSwitches)
            if (tank.computerId == null || sw.appliesTo(tank.computerId!))
              (t: sw.timestamp, tankKey: sw.tankId),
        ],
        isLoopTank: (id) => isLoopTankRole(roleById[id]?.name),
        pressures: {
          tank.id: [for (final s in series) (t: s.t, bar: s.bar)],
        },
        candidates: [tank.id],
        inWaterEndSeconds: inWaterEnd,
      );
      for (final e in evidence ?? const <BailoutEvidence<String>>[]) {
        out.add(
          make(
            ctx,
            discriminator: 'inactive:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'tankId': tank.id,
              'tankOrder': tank.order,
              'inactiveDropBar': e.ocDropBar,
              'totalDropBar': _totalDrop(series),
            },
          ),
        );
      }
    }
    return out;
  }

  /// [tank]'s own computer's reading, or the merged series when no computer
  /// owns it.
  static List<QualityPressureSample>? _ownSeries(
    DiveQualityContext ctx,
    DiveTank tank,
  ) =>
      ctx.ownComputerPressuresByTankId[tank.id] ??
      ctx.pressuresByTankId[tank.id];

  /// A name-derived loop role on a CCR dive, which `TransmitterRoleDetector`
  /// already judges by the same drain rates, with a repair that fixes the
  /// role. A second finding here would repeat it.
  static bool _leftToRoleCheck(DiveQualityContext ctx, DiveTank tank) =>
      ctx.dive.diveMode == DiveMode.ccr &&
      tank.roleSource == TankRoleSource.transmitterName;

  /// Sum of every pressure drop between consecutive samples.
  static double _totalDrop(List<QualityPressureSample> series) {
    var total = 0.0;
    for (var i = 1; i < series.length; i++) {
      final d = series[i - 1].bar - series[i].bar;
      if (d > 0) total += d;
    }
    return total;
  }

  static String? _serial(DiveTank tank) =>
      normalizeTransmitterSerial(tank.transmitterSerial);

  /// The series in ascending time order. Stored series already are, so the
  /// common case returns the input itself rather than cloning and sorting
  /// it for every tank pair of every dive in a library scan.
  static List<QualityPressureSample> _inTimeOrder(
    List<QualityPressureSample> series,
  ) {
    for (var i = 1; i < series.length; i++) {
      if (series[i].t < series[i - 1].t) {
        return [...series]..sort((x, y) => x.t.compareTo(y.t));
      }
    }
    return series;
  }

  /// Mean absolute pressure difference between two series at their nearest
  /// samples, or null when they never come within the gap tolerance of each
  /// other. Both series are compared in time order with a single walk.
  static ({int samples, double meanDiffBar})? _seriesAgreement(
    List<QualityPressureSample> a,
    List<QualityPressureSample> b,
  ) {
    if (a.isEmpty || b.isEmpty) return null;
    final sortedA = _inTimeOrder(a);
    final sortedB = _inTimeOrder(b);
    const gap = QualityThresholds.twinSeriesMaxTimeGapSeconds;
    var n = 0;
    var sum = 0.0;
    var j = 0;
    for (final p in sortedA) {
      while (j + 1 < sortedB.length &&
          (sortedB[j + 1].t - p.t).abs() <= (sortedB[j].t - p.t).abs()) {
        j++;
      }
      final q = sortedB[j];
      if ((q.t - p.t).abs() > gap) continue;
      n++;
      sum += (p.bar - q.bar).abs();
    }
    if (n == 0) return null;
    return (samples: n, meanDiffBar: sum / n);
  }
}
