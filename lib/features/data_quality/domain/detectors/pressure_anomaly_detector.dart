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
  // Bumped again when the consumption check stopped counting the
  // post-surfacing tail (#2224), for the same reason.
  // v4: slow rises no longer flagged (#2442), glitches (dropouts, spikes)
  // reported once per tank instead of as rises (#2441), series mixed from
  // two sources reported as such (#2440).
  @override
  int get version => 4;
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

      // What the series says about either end of the dive, or null where it
      // says nothing: a series that began logging late describes no start
      // (#2222), and one with no reading near surfacing describes no end
      // (#2220). Measured on the series without its glitches, so a lead-in
      // or a dropout never stands in for either end (#2441).
      final hasSeries = series.length >= 2;
      // A recorded start that matches a reading of the series' lead-in (the
      // glitches before its first clean reading) was taken from it, so the
      // series speaks to the start however late it began. A glitch later in
      // the dive says nothing about the start.
      var firstClean = 0;
      while (firstClean < raw.length &&
          glitches.glitchIndices.contains(firstClean)) {
        firstClean++;
      }
      final startFromGlitch =
          sp != null &&
          [for (var i = 0; i < firstClean; i++) raw[i]].any(
            (p) =>
                (p.bar - sp).abs() <= QualityThresholds.pressureGlitchMatchBar,
          );
      final startReferenceBar =
          hasSeries &&
              (startFromGlitch ||
                  series.first.t <=
                      QualityThresholds.pressureStartLookbackSeconds)
          ? series.first.bar
          : null;
      final endReferenceBar = hasSeries
          ? _endReferenceBar(series, surfacingTime)
          : null;

      if (sp != null &&
          ep != null &&
          ep - sp > QualityThresholds.pressureSwapMinDiffBar &&
          _seriesAllowsSwap(startReferenceBar, endReferenceBar, sp, ep)) {
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

      if (!hasSeries) continue;

      if (sp != null &&
          startReferenceBar != null &&
          (sp - startReferenceBar).abs() >
              QualityThresholds.pressureEndpointMismatchBar) {
        out.add(
          make(
            ctx,
            discriminator: 'startmismatch:${tank.id}',
            computerId: tank.computerId,
            severity: QualitySeverity.warning,
            params: {
              'recordBar': sp,
              'seriesBar': startReferenceBar,
              'tankId': tank.id,
              'tankOrder': tank.order,
              'endpoint': 'start',
            },
          ),
        );
      }
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
      // The steepest single step of the run, so a sudden jump is not
      // averaged away by a slow creep before or after it.
      var steepestBar = 0.0;
      var steepestSeconds = 0;
      void closeRise(int endT) {
        final start = riseStart;
        if (start != null &&
            _isAnomalousRise(
              rise,
              endT - start,
              steepestBar: steepestBar,
              steepestSeconds: steepestSeconds,
            ) &&
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
        steepestBar = 0;
        steepestSeconds = 0;
      }

      for (var i = 1; i < series.length; i++) {
        final d = series[i].bar - series[i - 1].bar;
        if (d > 0) {
          riseStart ??= series[i - 1].t;
          rise += d;
          if (d > steepestBar) {
            steepestBar = d;
            steepestSeconds = series[i].t - series[i - 1].t;
          }
        } else {
          closeRise(series[i - 1].t);
        }
      }
      closeRise(series.last.t);

      // Implausible surface-equivalent consumption.
      final window = _consumptionWindow(series, surfacingTime);
      if (window == null) continue;
      final drop = window.first.bar - window.last.bar;
      final durSec = window.last.t - window.first.t;
      final vol = tank.volume;
      if (drop > 0 &&
          durSec >= QualityThresholds.sacMinSeriesSeconds &&
          vol != null) {
        final avgDepth =
            ctx.dive.avgDepth ??
            _meanDepth(ctx.primarySamples, window.first.t, window.last.t);
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

  /// Whether the tank's pressure series, where it describes the start and
  /// end of the dive, agrees that the recorded start and end pressures were
  /// entered the wrong way round.
  ///
  /// A record whose start pressure was read before the valve was open (a
  /// few bar) also shows an end above its start, and swapping the two would
  /// make it worse. The series settles which it is: in a real swap the
  /// series starts near the recorded end and ends near the recorded start.
  /// Either reference is null where the series says nothing about that end
  /// of the dive, and a series that says nothing at all leaves the record
  /// as all there is to go by, so the swap stands.
  bool _seriesAllowsSwap(
    double? startReferenceBar,
    double? endReferenceBar,
    double startBar,
    double endBar,
  ) {
    const tolerance = QualityThresholds.pressureEndpointMismatchBar;
    if (startReferenceBar != null &&
        (startReferenceBar - endBar).abs() > tolerance) {
      return false;
    }
    if (endReferenceBar != null &&
        (endReferenceBar - startBar).abs() > tolerance) {
      return false;
    }
    return true;
  }

  /// Whether a rising run of [riseBar] over [durationSeconds] is an anomaly
  /// rather than a cylinder warming up or a drifting sensor (#2442).
  ///
  /// The run's steepest single step ([steepestBar] over [steepestSeconds])
  /// is judged on its own as well: a genuine jump next to a slow creep would
  /// otherwise be averaged below the rate gate.
  bool _isAnomalousRise(
    double riseBar,
    int durationSeconds, {
    required double steepestBar,
    required int steepestSeconds,
  }) {
    if (riseBar <= QualityThresholds.pressureRiseBar) return false;
    if (riseBar > QualityThresholds.pressureRiseAlwaysFlagBar) return true;
    if (_fasterThanRiseGate(riseBar, durationSeconds)) return true;
    return steepestBar > QualityThresholds.pressureRiseBar &&
        _fasterThanRiseGate(steepestBar, steepestSeconds);
  }

  bool _fasterThanRiseGate(double bar, int seconds) {
    // Timestamps never decrease, but two readings can share one; a rise
    // with no measurable duration is as fast as a rise can be.
    if (seconds <= 0) return true;
    return bar / (seconds / 60.0) >
        QualityThresholds.pressureRiseMinBarPerMinute;
  }

  /// The pair of samples to measure this tank's consumption rate between, or
  /// null when the series recorded no breathing at all.
  ///
  /// The window ends at the last sample at or before surfacing, for the same
  /// reason [_endReferenceBar] does: the post-surfacing tail can shed tens of
  /// bar that nobody breathed (#1092, #2220), and counting it inflates the
  /// rate into a false "implausible consumption" finding (#2224). Drop and
  /// duration both come from this one window, so the rate is never an
  /// underwater drop spread over a duration that includes the tail.
  ///
  /// Unlike the end check, no lookback applies. A rate measured over any
  /// stretch of the dive is still that dive's rate, so a transmitter that
  /// went quiet long before surfacing still has one to judge.
  ///
  /// When only the first sample falls underwater there is no underwater
  /// stretch to measure, so the whole series stands, as it did before #2224:
  /// a sparse start-and-end series cannot separate its tail, and suppressing
  /// the check would retire it for every such tank. A series that begins
  /// after surfacing is all tail and gets no window. Without depth data the
  /// whole series stands too.
  ({QualityPressureSample first, QualityPressureSample last})?
  _consumptionWindow(List<QualityPressureSample> series, int? surfacingTime) {
    if (surfacingTime == null) return (first: series.first, last: series.last);
    if (series.first.t > surfacingTime) return null;
    var atSurfacing = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i].t <= surfacingTime) atSurfacing = i;
    }
    if (atSurfacing == 0) return (first: series.first, last: series.last);
    return (first: series.first, last: series[atSurfacing]);
  }

  bool _nearSwitch(DiveQualityContext ctx, int startT, int endT) =>
      ctx.gasSwitches.any(
        (sw) =>
            sw.timestamp >= startT - QualityThresholds.switchProximitySeconds &&
            sw.timestamp <= endT + QualityThresholds.switchProximitySeconds,
      );

  /// Mean depth of the samples inside the consumption window [fromT]..[toT],
  /// so the ambient pressure a rate is normalized by covers the same stretch
  /// as its drop and duration: surface samples in the post-surfacing tail
  /// would otherwise make the dive read shallower and the rate higher
  /// (#2224). Falls back to every sample when none land in the window.
  double? _meanDepth(List<QualitySample> allSamples, int fromT, int toT) {
    final inWindow = [
      for (final s in allSamples)
        if (s.t >= fromT && s.t <= toT) s,
    ];
    final samples = inWindow.isEmpty ? allSamples : inWindow;
    if (samples.isEmpty) return null;
    var sum = 0.0;
    for (final p in samples) {
      sum += p.depth;
    }
    return sum / samples.length;
  }
}
