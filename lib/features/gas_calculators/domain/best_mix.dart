import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundDownTo;
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart'
    show ambientPressureAtDepth;

/// Standard mixes a fill station is likely to have, richest first.
const List<double> _standardO2Percentages = [50, 40, 36, 32, 30, 28, 21];

class BestMixInputs {
  final double depthMeters;
  final double ppO2Limit;
  final double endLimitMeters;
  final bool o2Narcotic;

  const BestMixInputs({
    required this.depthMeters,
    required this.ppO2Limit,
    required this.endLimitMeters,
    required this.o2Narcotic,
  });
}

/// A candidate mix scored against the target depth.
///
/// Every limit here belongs to THIS mix, not to the idealised fraction it was
/// rounded from. Showing a mix without its own MOD is how the previous
/// implementation recommended a gas that was already exceeded at depth.
class MixAssessment {
  final GasMix mix;

  /// MOD of this mix at the requested ppO2 limit.
  final double modMeters;

  /// How much deeper this mix may be taken than the target depth.
  /// Negative means the mix is already exceeded at the target depth.
  final double marginMeters;

  final double endMeters;
  final bool exceedsEndLimit;

  final double densityGPerL;
  final bool exceedsWarnDensity;
  final bool exceedsCriticalDensity;

  const MixAssessment({
    required this.mix,
    required this.modMeters,
    required this.marginMeters,
    required this.endMeters,
    required this.exceedsEndLimit,
    required this.densityGPerL,
    required this.exceedsWarnDensity,
    required this.exceedsCriticalDensity,
  });
}

class BestMixResult {
  /// The mix this calculator recommends. Carries helium when the diver's END
  /// limit requires it.
  final MixAssessment recommended;

  /// The best mix available without helium, present only when [recommended]
  /// contains helium.
  ///
  /// A recreational diver at 34 m is unlikely to be filling trimix, so the UI
  /// shows this alongside the recommendation with its own END and density so
  /// the trade-off is visible rather than implied.
  final MixAssessment? nitroxAlternative;

  /// The exact, unrounded ideal O2 percentage.
  final double idealO2Percent;

  /// Nearest commonly stocked nitrox whose MOD still covers the target depth.
  /// Advisory only, and never shallower than the dive.
  final GasMix? nearestStandardMix;

  const BestMixResult({
    required this.recommended,
    required this.nitroxAlternative,
    required this.idealO2Percent,
    required this.nearestStandardMix,
  });
}

MixAssessment _assess(GasMix mix, BestMixInputs inputs) {
  final ambient = ambientPressureAtDepth(inputs.depthMeters);
  final mod = mix.mod(ppO2: inputs.ppO2Limit);
  final end = mix.end(inputs.depthMeters, o2Narcotic: inputs.o2Narcotic);
  final density = gasDensityGPerL(
    fO2: mix.o2 / 100,
    fHe: mix.he / 100,
    ambientPressureBar: ambient,
  );

  return MixAssessment(
    mix: mix,
    modMeters: mod,
    marginMeters: mod - inputs.depthMeters,
    endMeters: end,
    exceedsEndLimit: end > inputs.endLimitMeters + 1e-9,
    densityGPerL: density,
    exceedsWarnDensity: density > gasDensityWarnGPerL,
    exceedsCriticalDensity: density > gasDensityCriticalGPerL,
  );
}

/// Compute the best breathing mix for a target depth.
///
/// Rounding is always toward safety: O2 DOWN to a whole percent, so the
/// recommended mix's MOD is at or beyond the target depth; helium UP to 5%, so
/// END lands at or inside the limit.
///
/// The previous implementation bucketed the ideal fraction UP into a named
/// mix, which at 111 ft recommended EAN32 -- whose own MOD at ppO2 1.4 is
/// 110.7 ft, shallower than the dive.
BestMixResult computeBestMix(BestMixInputs inputs) {
  final ambient = ambientPressureAtDepth(inputs.depthMeters);
  final ideal = inputs.ppO2Limit / ambient * 100;

  // Round DOWN so the resulting MOD is at or beyond the target depth.
  final o2 = roundDownTo(ideal, 1).clamp(1.0, 100.0);

  final nitrox = _assess(GasMix(o2: o2), inputs);

  // Helium only if the nitrox mix would exceed the narcosis limit.
  var recommended = nitrox;
  MixAssessment? alternative;
  if (nitrox.exceedsEndLimit) {
    final needed = GasMix.heForMnd(
      inputs.depthMeters,
      o2,
      endLimit: inputs.endLimitMeters,
      o2Narcotic: inputs.o2Narcotic,
    );
    // Round UP to a 5% increment: more helium is less narcosis.
    final he = ((needed / 5).ceil() * 5.0).clamp(0.0, 100.0 - o2);
    if (he > 0) {
      recommended = _assess(GasMix(o2: o2, he: he), inputs);
      alternative = nitrox;
    }
  }

  GasMix? nearest;
  for (final candidate in _standardO2Percentages) {
    final standard = GasMix(o2: candidate);
    if (standard.mod(ppO2: inputs.ppO2Limit) >= inputs.depthMeters) {
      nearest = standard;
      break;
    }
  }

  return BestMixResult(
    recommended: recommended,
    nitroxAlternative: alternative,
    idealO2Percent: ideal,
    nearestStandardMix: nearest,
  );
}
