import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

class TankAssignmentDetector extends QualityDetector {
  const TankAssignmentDetector();

  @override
  String get id => 'tank_assignment';
  @override
  int get version => 2;
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
    }
    return out;
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
