import 'dart:math' as math;

import 'package:submersion/core/buoyancy/body_composition.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';

/// The groups a diver's buoyancy is split into for the balance bar.
enum TwinBalancePartKind { lead, tanks, gear, suit, body }

/// One group's signed contribution: negative pulls the diver down, positive
/// holds them up.
class TwinBalancePart {
  final TwinBalancePartKind kind;
  final double kg;
  const TwinBalancePart({required this.kind, required this.kg});
}

/// What was pulling a diver down and holding them up at one moment of a dive.
///
/// The parts sum to [netKg] (give or take the parts dropped as negligible), so
/// a bar drawn from them agrees with the figure shown beside it.
class TwinBalance {
  /// A part or a change smaller than this is not worth showing.
  static const double negligibleKg = 0.05;

  /// Static term labels that describe the diver rather than their gear.
  static const Set<String> _bodyLabels = {
    'personal',
    'water',
    BodyComposition.termLabel,
  };

  /// The non-negligible parts, in [TwinBalancePartKind] order.
  final List<TwinBalancePart> parts;
  final double netKg;

  const TwinBalance({required this.parts, required this.netKg});

  List<TwinBalancePart> get down => [
    for (final p in parts)
      if (p.kg < 0) p,
  ];

  List<TwinBalancePart> get up => [
    for (final p in parts)
      if (p.kg > 0) p,
  ];

  /// Total pulling down, as a positive magnitude.
  double get downTotalKg => down.fold(0.0, (sum, p) => sum - p.kg);

  /// Total holding up.
  double get upTotalKg => up.fold(0.0, (sum, p) => sum + p.kg);

  /// The balance at the verdict's anchor: the final stop, or the safety-stop
  /// convention for a dive with no profile.
  factory TwinBalance.atRest(BuoyancyTwinResult result, TwinVerdict verdict) {
    final hasSuit =
        result.input.suit.kind != TwinSuitKind.none &&
        verdict.terms.isNotEmpty &&
        verdict.terms.first.label == 'suit';
    final suitKg = hasSuit ? verdict.terms.first.kg : 0.0;
    final staticKg = result.input.staticTerms.fold(0.0, (s, t) => s + t.kg);
    final tanksKg = verdict.netKg - suitKg - staticKg + result.input.leadKg;
    return TwinBalance._build(
      result,
      suitKg: suitKg,
      tanksKg: tanksKg,
      staticKg: staticKg,
      netKg: verdict.netKg,
    );
  }

  /// The balance at one sample of the dive.
  factory TwinBalance.atSample(BuoyancyTwinResult result, TwinSample sample) {
    return TwinBalance._build(
      result,
      suitKg: sample.suitKg,
      tanksKg: sample.tanksKg,
      // Whatever the sample's net holds beyond suit, tanks and lead is the
      // constant body-and-gear part, so the parts always sum to the net.
      staticKg:
          sample.netKg - sample.suitKg - sample.tanksKg + result.input.leadKg,
      netKg: sample.netKg,
    );
  }

  factory TwinBalance._build(
    BuoyancyTwinResult result, {
    required double suitKg,
    required double tanksKg,
    required double staticKg,
    required double netKg,
  }) {
    final bodyKg = result.input.staticTerms
        .where((t) => _bodyLabels.contains(t.label))
        .fold(0.0, (s, t) => s + t.kg);
    final byKind = {
      TwinBalancePartKind.lead: -result.input.leadKg,
      TwinBalancePartKind.tanks: tanksKg,
      TwinBalancePartKind.gear: staticKg - bodyKg,
      TwinBalancePartKind.suit: suitKg,
      TwinBalancePartKind.body: bodyKg,
    };
    return TwinBalance(
      parts: [
        for (final kind in TwinBalancePartKind.values)
          if (byKind[kind]!.isFinite && byKind[kind]!.abs() >= negligibleKg)
            TwinBalancePart(kind: kind, kg: byKind[kind]!),
      ],
      netKg: netKg,
    );
  }

  /// The largest side total across every sample and the rest state. A bar
  /// scaled by it keeps the constant parts still while the dive is scrubbed.
  static double scaleKg(BuoyancyTwinResult result, TwinVerdict verdict) {
    var scale = _largestSide(TwinBalance.atRest(result, verdict));
    for (final sample in result.samples) {
      if (!sample.netKg.isFinite) continue;
      scale = math.max(
        scale,
        _largestSide(TwinBalance.atSample(result, sample)),
      );
    }
    return math.max(scale, negligibleKg);
  }

  static double _largestSide(TwinBalance b) =>
      math.max(b.downTotalKg, b.upTotalKg);
}

/// The moments and causes the Buoyancy card names on its chart.
class TwinMoments {
  /// The first sample below the surface band.
  final TwinSample? start;

  /// The sample at the greatest depth.
  final TwinSample? deepest;

  /// When the verdict was judged; null for the no-profile convention.
  final int? finalStopSeconds;

  /// Lift a wetsuit lost between [start] and [deepest]; null for any other
  /// suit and when negligible.
  final double? suitSqueezeKg;

  /// How much lighter the tanks ended than they began; null when negligible.
  final double? gasLighterKg;

  const TwinMoments({
    required this.start,
    required this.deepest,
    required this.finalStopSeconds,
    required this.suitSqueezeKg,
    required this.gasLighterKg,
  });

  factory TwinMoments.of(BuoyancyTwinResult result, TwinVerdict verdict) {
    final samples = result.samples;
    TwinSample? start;
    TwinSample? deepest;
    for (final s in samples) {
      if (start == null && s.depthM > TwinAnalyzer.kSurfaceDepthM) start = s;
      if (deepest == null || s.depthM > deepest.depthM) deepest = s;
    }

    double? squeeze;
    if (result.input.suit.kind == TwinSuitKind.wetsuit &&
        start != null &&
        deepest != null) {
      squeeze = _meaningful(start.suitKg - deepest.suitKg);
    }

    final lighter = samples.isEmpty || result.input.tanks.isEmpty
        ? null
        : _meaningful(samples.last.tanksKg - samples.first.tanksKg);

    return TwinMoments(
      start: start,
      deepest: deepest,
      finalStopSeconds: verdict.anchor.kind == TwinAnchorKind.convention
          ? null
          : verdict.anchor.timestamp,
      suitSqueezeKg: squeeze,
      gasLighterKg: lighter,
    );
  }

  static double? _meaningful(double kg) =>
      kg.isFinite && kg >= TwinBalance.negligibleKg ? kg : null;
}
