import 'dart:math' as math;

/// The depths at which an ascent leg from [fromDepth] to [toDepth] (an
/// ascent: [fromDepth] deeper than [toDepth]) should be broken into its
/// own gas, each boundary one of [ascentPlan]'s own switch depths between
/// them, in travel order (deep to shallow) -- so a leg spanning more than
/// one carried gas's MOD uses every gas actually eligible across it,
/// instead of only the one valid at [fromDepth] (#3225).
///
/// A leg with nothing eligible strictly between its ends gets exactly its
/// two endpoints back, unsplit: `[fromDepth, toDepth]`. A normal
/// inter-stop leg is this unsplit case, because a switch at a gas's MOD lands
/// exactly at a stop. This does its real work on a leg spanning more than the
/// usual 3 m between two deco stops, chiefly the bottom-to-first-stop leg, and
/// on any leg holding a switch depth the diver set by hand.
List<double> travelLegBoundaries(
  AscentGasPlan ascentPlan, {
  required double fromDepth,
  required double toDepth,
}) => [
  fromDepth,
  ...ascentPlan.switchDepthsBetween(fromDepth, toDepth),
  toDepth,
];

/// Inert gas fractions to breathe at a given simulated ascent depth.
class AscentGas {
  const AscentGas({required this.fN2, required this.fHe});
  final double fN2;
  final double fHe;

  /// The oxygen left after the inert gases. On a rebreather loop the
  /// fractions are normalized against alveolar pressure, so this is not an
  /// inspired fraction: ask `LoopAscentGas.inspiredPpO2At` for the ppO2.
  double get fO2 => 1.0 - fN2 - fHe;
}

/// Strategy answering "what do I breathe at this ascent depth?" so the
/// Buhlmann algorithm stays ignorant of tank roles and ppO2 policy.
abstract class AscentGasPlan {
  /// Gas to breathe at [depthMeters] during a simulated ascent.
  AscentGas gasForDepth(double depthMeters);

  /// Depths in the open interval ([shallowerDepth], [deeperDepth]) where the
  /// selected gas changes, sorted deep-to-shallow (descending). An ascent leg
  /// is split at each so it never breathes a gas impermissible at its depth.
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth);

  /// Best gas to breathe during an air break at [depthMeters] — the eligible
  /// gas that is NOT effectively pure O2 and not hypoxic, whose fO2 is
  /// closest to air's (0.21). Null when the plan has no such alternative (no
  /// air breaks possible).
  AscentGas? breakGasForDepth(double depthMeters) => null;
}

/// Today's behavior: one gas the whole way up. Used by single-gas dives and the
/// planner's fixed-gas path. Reduces gas-aware ascent to the legacy ascent.
class FixedAscentGas extends AscentGasPlan {
  FixedAscentGas({required this.fN2, this.fHe = 0.0});
  final double fN2;
  final double fHe;

  @override
  AscentGas gasForDepth(double depthMeters) => AscentGas(fN2: fN2, fHe: fHe);

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) =>
      const [];
}

/// A cylinder available on the dive, with its precomputed switch depth for
/// the diver's ppO2 ceiling. [maxPpO2Mod] is the deepest depth (m) the gas
/// may be breathed from; the planner derives it with `gasSwitchDepthMeters`,
/// which allows a ppO2 that still reads as the ceiling.
class AvailableGas {
  const AvailableGas({
    required this.fN2,
    required this.fHe,
    required this.maxPpO2Mod,
  });
  final double fN2;
  final double fHe;
  final double maxPpO2Mod;

  double get fO2 => (1.0 - fN2 - fHe);

  /// Eligible when at or above its MOD (depth <= MOD). A tiny tolerance keeps
  /// the gas eligible exactly at its MOD despite float rounding.
  bool eligibleAt(double depthMeters) => depthMeters <= maxPpO2Mod + 1e-9;
}

/// Open-circuit optimal ascent: at each depth picks the eligible gas with the
/// highest O2 within [maxPpO2]. Eligibility is expressed as a depth on
/// [AvailableGas.maxPpO2Mod], derived once by the caller (the planner uses
/// `gasSwitchDepthMeters` in the plan's water) so ppO2 is never re-derived
/// here.
class OptimalOcAscentGas extends AscentGasPlan {
  OptimalOcAscentGas({required List<AvailableGas> gases, required this.maxPpO2})
    : assert(gases.isNotEmpty, 'OptimalOcAscentGas requires at least one gas'),
      _gases = List.unmodifiable(gases);

  final List<AvailableGas> _gases;
  final double maxPpO2;

  /// The gases this plan chooses from, in the order given.
  List<AvailableGas> get gases => _gases;

  /// The deepest depth any of these gases may be breathed from. Each gas is
  /// eligible from its MOD all the way up, so this one depth says how much of
  /// an ascent they cover: there are no gaps above it.
  double get deepestMod => _gases.map((g) => g.maxPpO2Mod).reduce(math.max);

  /// Whether any gas is eligible at [depthMeters]. A depth this rejects still
  /// gets an answer from [gasForDepth], which has to return something, so a
  /// caller that must not breathe a gas past its MOD asks here first (issue
  /// #3961).
  bool coversDepth(double depthMeters) =>
      _gases.any((g) => g.eligibleAt(depthMeters));

  @override
  AscentGas gasForDepth(double depthMeters) {
    AvailableGas? best;
    for (final g in _gases) {
      if (g.eligibleAt(depthMeters)) {
        if (best == null || _prefer(g, best)) best = g;
      }
    }
    // Nothing is eligible past every MOD. That is ordinary for a logged dive
    // that went past them, and a planner bailout carrying only shallow gas:
    // see [coversDepth]. Answer with the gas that is closest to usable there
    // (smallest fO2), which is not a claim that it is within its MOD.
    best ??= _deepestUsable();
    return AscentGas(fN2: best.fN2, fHe: best.fHe);
  }

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) {
    final result = <double>[];
    for (final g in _gases) {
      final mod = g.maxPpO2Mod;
      if (mod > shallowerDepth + 1e-9 && mod < deeperDepth - 1e-9) {
        // Only a real switch: the selected gas differs just below vs just above.
        final below = gasForDepth(mod + 1e-6);
        final above = gasForDepth(mod - 1e-6);
        if (below.fN2 != above.fN2 || below.fHe != above.fHe) {
          result.add(mod);
        }
      }
    }
    result.sort((a, b) => b.compareTo(a)); // descending (deep to shallow)
    return result;
  }

  /// Prefer higher O2; tie-break by lower narcotic load (higher He), then a
  /// deterministic order so the result is stable.
  bool _prefer(AvailableGas candidate, AvailableGas current) {
    if (candidate.fO2 != current.fO2) return candidate.fO2 > current.fO2;
    if (candidate.fHe != current.fHe) return candidate.fHe > current.fHe;
    return candidate.fN2 < current.fN2;
  }

  AvailableGas _deepestUsable() =>
      _gases.reduce((a, b) => a.fO2 <= b.fO2 ? a : b);

  /// Prefer the fO2 closest to air's (0.21) - an air break is meant to give
  /// the tissues a rest from a high ppO2, not to switch to another rich mix -
  /// tie-break by lower helium (less narcotic-load carryover), then lower
  /// fO2, so the result is stable.
  bool _preferBreakGas(AvailableGas candidate, AvailableGas current) {
    const airFO2 = 0.21;
    final candidateDist = (candidate.fO2 - airFO2).abs();
    final currentDist = (current.fO2 - airFO2).abs();
    if (candidateDist != currentDist) return candidateDist < currentDist;
    if (candidate.fHe != current.fHe) return candidate.fHe < current.fHe;
    return candidate.fO2 < current.fO2;
  }

  @override
  AscentGas? breakGasForDepth(double depthMeters) {
    AvailableGas? best;
    for (final g in _gases) {
      if (g.fO2 >= 0.9) continue; // skip O2 itself
      if (g.fO2 < 0.16) continue; // skip hypoxic back gas
      if (g.eligibleAt(depthMeters)) {
        if (best == null || _preferBreakGas(g, best)) best = g;
      }
    }
    if (best == null) return null;
    return AscentGas(fN2: best.fN2, fHe: best.fHe);
  }
}
