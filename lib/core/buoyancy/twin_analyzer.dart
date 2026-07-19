import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/suit_compression.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart'
    show TermSource;

/// How the final-stop anchor was chosen.
enum TwinAnchorKind { detectedStop, shallowWindow, convention }

/// The point at which the final-stop diagnosis is evaluated.
class TwinAnchor {
  final TwinAnchorKind kind;
  final int timestamp; // -1 for the profile-less convention
  final double depthM;
  const TwinAnchor({
    required this.kind,
    required this.timestamp,
    required this.depthM,
  });
}

/// The diagnosis at the anchor: net buoyancy and the term breakdown that
/// sums to it (suit, each tank, statics, and a negative lead term).
class TwinVerdict {
  final TwinAnchor anchor;
  final double netKg;
  final List<TwinStaticTerm> terms;
  const TwinVerdict({
    required this.anchor,
    required this.netKg,
    required this.terms,
  });
}

/// Every derived output the UI surfaces present.
class TwinOutputs {
  final double beginNetKg;
  final double endNetKg;
  final double peakLiftDemandKg;
  final double minDitchableKg;
  final double droppableLeadKg;
  final double idealLeadKg;
  final TwinVerdict verdict;
  final double drysuitGasLiters;
  const TwinOutputs({
    required this.beginNetKg,
    required this.endNetKg,
    required this.peakLiftDemandKg,
    required this.minDitchableKg,
    required this.droppableLeadKg,
    required this.idealLeadKg,
    required this.verdict,
    required this.drysuitGasLiters,
  });
}

/// Detects the final-stop anchor and computes the derived buoyancy outputs
/// from a [BuoyancyTwinResult].
class TwinAnalyzer {
  static const double kAnchorMaxDepthM = 9.0;
  static const double kAnchorMaxRangeM = 1.5;
  static const int kAnchorMinDurationS = 60;
  static const double kSurfaceDepthM = 1.0;
  static const double kDitchableMarginKg = 2.0;
  static const double _conventionDepthM = 5.0;

  static TwinOutputs analyze(BuoyancyTwinResult result) {
    final input = result.input;
    final samples = result.samples;
    final anchor = _detectAnchor(samples);
    final verdict = _verdictAt(result, anchor);

    final inWater = samples.where((s) => s.depthM > kSurfaceDepthM).toList();
    final double beginNet;
    final double endNet;
    final double worstNet;
    final double peakLift;
    if (inWater.isNotEmpty) {
      beginNet = inWater.first.netKg;
      endNet = inWater.last.netKg;
      worstNet = samples.map((s) => s.netKg).reduce((a, b) => a < b ? a : b);
      peakLift = samples
          .map((s) => s.netKg < 0 ? -s.netKg : 0.0)
          .fold(0.0, (m, v) => v > m ? v : m);
    } else {
      // No in-water samples (profile-less dive): evaluate statically. Full
      // tanks at the start are the heaviest, so begin is the worst case.
      beginNet = _staticNet(result, _conventionDepthM, useStart: true);
      endNet = _staticNet(result, _conventionDepthM, useStart: false);
      worstNet = beginNet;
      peakLift = beginNet < 0 ? -beginNet : 0.0;
    }

    final minDitchable = (kDitchableMarginKg - worstNet).clamp(
      0.0,
      double.infinity,
    );
    final idealLead = (input.leadKg + verdict.netKg).clamp(
      0.0,
      double.infinity,
    );

    return TwinOutputs(
      beginNetKg: beginNet,
      endNetKg: endNet,
      peakLiftDemandKg: peakLift,
      minDitchableKg: minDitchable,
      droppableLeadKg: input.droppableLeadKg,
      idealLeadKg: idealLead,
      verdict: verdict,
      drysuitGasLiters: result.drysuitGasLiters,
    );
  }

  static TwinAnchor _detectAnchor(List<TwinSample> samples) {
    if (samples.isEmpty) {
      return const TwinAnchor(
        kind: TwinAnchorKind.convention,
        timestamp: -1,
        depthM: _conventionDepthM,
      );
    }

    int? bestStart;
    int? bestEnd;
    var runStart = -1;
    var runMin = 0.0;
    var runMax = 0.0;

    void closeRun(int endIdx) {
      if (runStart < 0) return;
      final duration = samples[endIdx].timestamp - samples[runStart].timestamp;
      if (duration >= kAnchorMinDurationS) {
        bestStart = runStart;
        bestEnd = endIdx;
      }
    }

    for (var i = 0; i < samples.length; i++) {
      final d = samples[i].depthM;
      final inBand = d > kSurfaceDepthM && d <= kAnchorMaxDepthM;
      if (!inBand) {
        closeRun(i - 1);
        runStart = -1;
        continue;
      }
      if (runStart < 0) {
        runStart = i;
        runMin = d;
        runMax = d;
      } else {
        final newMin = d < runMin ? d : runMin;
        final newMax = d > runMax ? d : runMax;
        if (newMax - newMin > kAnchorMaxRangeM) {
          closeRun(i - 1);
          runStart = i;
          runMin = d;
          runMax = d;
        } else {
          runMin = newMin;
          runMax = newMax;
        }
      }
    }
    closeRun(samples.length - 1);

    final bs = bestStart;
    final be = bestEnd;
    if (bs != null && be != null) {
      final mid = (bs + be) ~/ 2;
      return TwinAnchor(
        kind: TwinAnchorKind.detectedStop,
        timestamp: samples[mid].timestamp,
        depthM: samples[mid].depthM,
      );
    }
    return _shallowWindowAnchor(samples);
  }

  static TwinAnchor _shallowWindowAnchor(List<TwinSample> samples) {
    final firstTs = samples.first.timestamp;
    final lastTs = samples.last.timestamp;
    final cutoff = firstTs + (lastTs - firstTs) * 2 / 3;
    final candidates = samples
        .where((s) => s.timestamp >= cutoff && s.depthM > kSurfaceDepthM)
        .toList();

    if (candidates.isEmpty) {
      final inWater = samples.where((s) => s.depthM > kSurfaceDepthM).toList();
      final chosen = inWater.isEmpty
          ? samples.last
          : (inWater..sort((a, b) => a.depthM.compareTo(b.depthM))).first;
      return TwinAnchor(
        kind: TwinAnchorKind.shallowWindow,
        timestamp: chosen.timestamp,
        depthM: chosen.depthM,
      );
    }

    double windowMean(TwinSample center) {
      final w = candidates
          .where((s) => (s.timestamp - center.timestamp).abs() <= 30)
          .map((s) => s.depthM)
          .toList();
      return w.reduce((a, b) => a + b) / w.length;
    }

    candidates.sort((a, b) => windowMean(a).compareTo(windowMean(b)));
    final chosen = candidates.first;
    return TwinAnchor(
      kind: TwinAnchorKind.shallowWindow,
      timestamp: chosen.timestamp,
      depthM: chosen.depthM,
    );
  }

  static double _suitAt(BuoyancyTwinResult result, double depthM) {
    final input = result.input;
    switch (input.suit.kind) {
      case TwinSuitKind.none:
        return 0.0;
      case TwinSuitKind.drysuit:
        return input.suit.anchorKg;
      case TwinSuitKind.wetsuit:
        return SuitCompression.buoyancyAtPressure(
          surfaceKg: result.suitSurfaceKg,
          pressureBar: input.environment.pressureAtDepth(depthM),
          surfacePressureBar: input.environment.surfacePressureBar,
        );
    }
  }

  static double _staticNet(
    BuoyancyTwinResult result,
    double depthM, {
    required bool useStart,
  }) {
    final input = result.input;
    var tanksKg = 0.0;
    for (final tank in input.tanks) {
      final pressure = useStart
          ? (tank.startPressureBar ?? tank.workingPressureBar ?? 200.0)
          : (tank.endPressureBar ?? BuoyancyPhysics.defaultReserveBar);
      tanksKg += twinTankKgAt(tank, pressure);
    }
    return _suitAt(result, depthM) + tanksKg + result.staticKg - input.leadKg;
  }

  static TwinVerdict _verdictAt(BuoyancyTwinResult result, TwinAnchor anchor) {
    final input = result.input;
    final terms = <TwinStaticTerm>[];

    if (input.suit.kind != TwinSuitKind.none) {
      terms.add(
        TwinStaticTerm(
          label: 'suit',
          kg: _suitAt(result, anchor.depthM),
          source: input.suit.source,
        ),
      );
    }

    final firstTs = result.samples.isEmpty ? 0 : result.samples.first.timestamp;
    final lastTs = result.samples.isEmpty ? 0 : result.samples.last.timestamp;
    for (final tank in input.tanks) {
      final pressure = anchor.kind == TwinAnchorKind.convention
          ? (tank.endPressureBar ?? BuoyancyPhysics.defaultReserveBar)
          : twinTankPressureAt(tank, anchor.timestamp, firstTs, lastTs);
      terms.add(
        TwinStaticTerm(
          label: tank.label,
          kg: twinTankKgAt(tank, pressure),
          source: TermSource.physics,
        ),
      );
    }

    terms.addAll(input.staticTerms);
    terms.add(
      TwinStaticTerm(
        label: 'lead',
        kg: -input.leadKg,
        source: TermSource.measured,
      ),
    );

    final net = terms.fold(0.0, (s, t) => s + t.kg);
    return TwinVerdict(anchor: anchor, netKg: net, terms: terms);
  }
}
