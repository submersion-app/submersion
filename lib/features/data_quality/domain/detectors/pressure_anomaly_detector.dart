import 'package:submersion/core/profile/surfacing_pressure.dart'
    show lastTimeBelowSurfaceThreshold;
import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/core/profile/tank_pressure_mixing.dart';
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
  // v3: slow rises no longer flagged (#2442), signal dropouts reported once
  // per tank instead of as rises (#2441), series mixed from two sources
  // reported as such (#2440).
  @override
  int get version => 3;
  @override
  QualityCategory get category => QualityCategory.pressure;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final surfacingTime = lastTimeBelowSurfaceThreshold(
      ctx.primarySamples.map((s) => (t: s.t, depth: s.depth)),
    );
    for (final tank in ctx.tanks) {
      final raw = ctx.pressuresByTankId[tank.id] ?? const [];
      final sp = tank.startPressure;
      final ep = tank.endPressure;
      final readings = [for (final p in raw) (t: p.t, bar: p.bar)];

      // Two recordings interleaved into one series (#2440) are reported as
      // that and nothing else: every alternation would read as a rise, the
      // lower track as dropouts, and either end as a mismatch. Checked first,
      // before the dropout scan takes the lower track for misreads. Only a
      // dive with more than one source can hold two recordings.
      if (ctx.sources.length > 1 && looksLikeInterleavedSources(readings)) {
        out.add(
          make(
            ctx,
            discriminator: 'mixed:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'mixedSources': true,
              'tankId': tank.id,
              'tankOrder': tank.order,
            },
          ),
        );
        continue;
      }

      // Dropouts and transient misreads are reported once per tank, and
      // every other check reads the series without them: each recovery from
      // a dropout would otherwise read as a mid-dive rise, and a dropout at
      // either end as an endpoint mismatch (#2441).
      final glitches = scanPressureGlitches(readings);
      final series = glitches.glitchIndices.isEmpty
          ? raw
          : [
              for (var i = 0; i < raw.length; i++)
                if (!glitches.glitchIndices.contains(i)) raw[i],
            ];
      if (glitches.episodeCount > 0) {
        out.add(
          make(
            ctx,
            discriminator: 'dropout:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'dropoutCount': glitches.episodeCount,
              'tankId': tank.id,
              'tankOrder': tank.order,
            },
          ),
        );
      }

      if (sp != null &&
          ep != null &&
          ep - sp > QualityThresholds.pressureSwapMinDiffBar &&
          _seriesAllowsSwap(series, sp, ep)) {
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

      // The lookback asks when the series began logging, so it reads the
      // raw first sample: a lead-in dropped above says nothing about that.
      if (sp != null &&
          raw.first.t <= QualityThresholds.pressureStartLookbackSeconds &&
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
        final start = riseStart;
        if (start != null &&
            _isAnomalousRise(rise, endT - start) &&
            !_nearSwitch(ctx, start, endT)) {
          out.add(
            make(
              ctx,
              discriminator: 'rise:${tank.id}:${start ~/ 60}',
              computerId: tank.computerId,
              severity: QualitySeverity.warning,
              params: {
                'riseBar': rise,
                'startSeconds': start,
                'durationSeconds': endT - start,
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

  /// Whether the tank's pressure series, if it has one, agrees that the
  /// recorded start and end pressures were entered the wrong way round.
  ///
  /// A record whose start pressure came from a dropout (1 to 12 bar) also
  /// shows an end above its start, and swapping the two would make it
  /// worse. The series settles which it is: a real swap drains from the
  /// recorded end down to the recorded start. Without a series the record
  /// is all there is to go by, so the swap stands.
  bool _seriesAllowsSwap(
    List<QualityPressureSample> series,
    double startBar,
    double endBar,
  ) {
    if (series.length < 2) return true;
    const tolerance = QualityThresholds.pressureEndpointMismatchBar;
    return (series.first.bar - endBar).abs() <= tolerance &&
        (series.last.bar - startBar).abs() <= tolerance;
  }

  /// Whether a rising run of [riseBar] over [durationSeconds] is an anomaly
  /// rather than a cylinder warming up or a drifting sensor (#2442).
  bool _isAnomalousRise(double riseBar, int durationSeconds) {
    if (riseBar <= QualityThresholds.pressureRiseBar) return false;
    if (riseBar > QualityThresholds.pressureRiseAlwaysFlagBar) return true;
    // Timestamps never decrease, but two readings can share one; a rise
    // with no measurable duration is as fast as a rise can be.
    if (durationSeconds <= 0) return true;
    return riseBar / (durationSeconds / 60.0) >
        QualityThresholds.pressureRiseMinBarPerMinute;
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
