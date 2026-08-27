import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class TankAssignmentDetector extends QualityDetector {
  const TankAssignmentDetector();

  @override
  String get id => 'tank_assignment';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    if (ctx.tanks.length < 2) return const [];
    final out = <QualityFinding>[];

    // Double-assigned transmitter: two tanks carrying the same series.
    final tankIds = ctx.pressuresByTankId.keys.toList()..sort();
    for (var i = 0; i < tankIds.length; i++) {
      for (var j = i + 1; j < tankIds.length; j++) {
        final a = ctx.pressuresByTankId[tankIds[i]]!;
        final b = {
          for (final p in ctx.pressuresByTankId[tankIds[j]]!) p.t: p.bar,
        };
        var n = 0;
        var sum = 0.0;
        for (final p in a) {
          final q = b[p.t];
          if (q != null) {
            n++;
            sum += (p.bar - q).abs();
          }
        }
        if (n >= QualityThresholds.twinSeriesMinSamples &&
            sum / n < QualityThresholds.twinSeriesMeanDiffBar) {
          out.add(
            make(
              ctx,
              discriminator: 'twin:${tankIds[i]}|${tankIds[j]}',
              severity: QualitySeverity.warning,
              params: {
                'tankIdA': tankIds[i],
                'tankIdB': tankIds[j],
                'meanDiffBar': sum / n,
              },
            ),
          );
        }
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
}
