import 'package:submersion/core/profile/surfacing_pressure.dart'
    show lastTimeBelowSurfaceThreshold;
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';

class PressureAnomalyDetector extends QualityDetector {
  const PressureAnomalyDetector();

  @override
  String get id => 'pressure_anomaly';
  // Bumped for the endmismatch/startmismatch surfacing-lookback logic
  // (#2220, #2222): divers who already ran a full scan at v1 need the
  // "new checks available" prompt so their stale false positives retire.
  @override
  int get version => 2;
  @override
  QualityCategory get category => QualityCategory.pressure;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final surfacingTime = lastTimeBelowSurfaceThreshold(
      ctx.primarySamples.map((s) => (t: s.t, depth: s.depth)),
    );
    for (final tank in ctx.tanks) {
      final series = ctx.pressuresByTankId[tank.id] ?? const [];
      final sp = tank.startPressure;
      final ep = tank.endPressure;

      if (sp != null &&
          ep != null &&
          ep - sp > QualityThresholds.pressureSwapMinDiffBar) {
        out.add(
          make(
            ctx,
            discriminator: 'swap:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'startBar': sp,
              'endBar': ep,
              'tankId': tank.id,
              'tankOrder': tank.order,
            },
          ),
        );
      }

      if (series.length < 2) continue;

      if (sp != null &&
          series.first.t <= QualityThresholds.pressureStartLookbackSeconds &&
          (sp - series.first.bar).abs() >
              QualityThresholds.pressureEndpointMismatchBar) {
        out.add(
          make(
            ctx,
            discriminator: 'startmismatch:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'recordBar': sp,
              'seriesBar': series.first.bar,
              'tankId': tank.id,
              'tankOrder': tank.order,
              'endpoint': 'start',
            },
          ),
        );
      }
      final endReferenceBar = _endReferenceBar(series, surfacingTime);
      if (ep != null &&
          endReferenceBar != null &&
          (ep - endReferenceBar).abs() >
              QualityThresholds.pressureEndpointMismatchBar) {
        out.add(
          make(
            ctx,
            discriminator: 'endmismatch:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'recordBar': ep,
              'seriesBar': endReferenceBar,
              'tankId': tank.id,
              'tankOrder': tank.order,
              'endpoint': 'end',
            },
          ),
        );
      }

      // Mid-dive rising runs away from any gas switch.
      var rise = 0.0;
      int? riseStart;
      void closeRise(int endT) {
        if (rise > QualityThresholds.pressureRiseBar &&
            riseStart != null &&
            !_nearSwitch(ctx, riseStart!, endT)) {
          out.add(
            make(
              ctx,
              discriminator: 'rise:${tank.id}:${riseStart! ~/ 60}',
              computerId: tank.computerId,
              severity: QualitySeverity.warning,
              params: {
                'riseBar': rise,
                'startSeconds': riseStart,
                'tankId': tank.id,
                'tankOrder': tank.order,
              },
            ),
          );
        }
        rise = 0;
        riseStart = null;
      }

      for (var i = 1; i < series.length; i++) {
        final d = series[i].bar - series[i - 1].bar;
        if (d > 0) {
          riseStart ??= series[i - 1].t;
          rise += d;
        } else {
          closeRise(series[i - 1].t);
        }
      }
      closeRise(series.last.t);

      // Implausible surface-equivalent consumption.
      final drop = series.first.bar - series.last.bar;
      final durSec = series.last.t - series.first.t;
      final vol = tank.volume;
      if (drop > 0 &&
          durSec >= QualityThresholds.sacMinSeriesSeconds &&
          vol != null) {
        final avgDepth = ctx.dive.avgDepth ?? _meanDepth(ctx.primarySamples);
        if (avgDepth != null) {
          final atm = 1 + avgDepth / 10;
          final surfaceLpm = drop * vol / (durSec / 60.0) / atm;
          if (surfaceLpm > QualityThresholds.sacSurfaceLpmMax) {
            out.add(
              make(
                ctx,
                discriminator: 'sac:${tank.id}',
                computerId: tank.computerId,
                severity: QualitySeverity.warning,
                params: {
                  'surfaceLpm': surfaceLpm,
                  'dropBar': drop,
                  'volumeLiters': vol,
                  'tankId': tank.id,
                  'tankOrder': tank.order,
                },
              ),
            );
          }
        }
      }
    }
    return out;
  }

  /// The pressure to treat as this tank's end-of-dive reading, or null when
  /// the series holds nothing that describes the end of the dive.
  ///
  /// The reading used is the last sample at or before surfacing, never a
  /// later one. A dive computer keeps recording for a while after the diver
  /// surfaces, and on some sources (notably a rebreather bleeding its O2
  /// supply down through a mass-flow orifice) that tail reads well below the
  /// pressure the cylinder actually held at surfacing: that is the exact drop
  /// the surfacing-pressure import fix corrects the reported end pressure for
  /// (#1092, #2220). Comparing against the raw last sample would flag every
  /// dive that fix already handled correctly.
  ///
  /// That sample must itself have been taken close to surfacing
  /// ([QualityThresholds.pressureSurfacingLookbackSeconds]). A tank series
  /// sampled far more sparsely than the depth series (in the extreme, just a
  /// start and an end reading) carries no reading that describes the end of
  /// the dive at all, and neither a stale early-dive pressure nor the tail
  /// above can stand in for one, so the comparison is suppressed instead.
  /// This mirrors the start check, which drops out the same way when the
  /// first sample lands too late to say anything about the reported start
  /// pressure (#2222).
  ///
  /// Without depth data there is no surfacing moment to measure anything
  /// against, so the last sample stands as the end reading, as it did before
  /// #2220.
  double? _endReferenceBar(
    List<QualityPressureSample> series,
    int? surfacingTime,
  ) {
    if (surfacingTime == null) return series.last.bar;
    QualityPressureSample? atSurfacing;
    for (final p in series) {
      if (p.t <= surfacingTime) atSurfacing = p;
    }
    if (atSurfacing == null ||
        surfacingTime - atSurfacing.t >
            QualityThresholds.pressureSurfacingLookbackSeconds) {
      return null;
    }
    return atSurfacing.bar;
  }

  bool _nearSwitch(DiveQualityContext ctx, int startT, int endT) =>
      ctx.gasSwitches.any(
        (sw) =>
            sw.timestamp >= startT - QualityThresholds.switchProximitySeconds &&
            sw.timestamp <= endT + QualityThresholds.switchProximitySeconds,
      );

  double? _meanDepth(List<QualitySample> samples) {
    if (samples.isEmpty) return null;
    var sum = 0.0;
    for (final p in samples) {
      sum += p.depth;
    }
    return sum / samples.length;
  }
}
