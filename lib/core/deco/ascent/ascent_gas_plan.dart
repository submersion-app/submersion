/// Inert gas fractions to breathe at a given simulated ascent depth.
class AscentGas {
  const AscentGas({required this.fN2, required this.fHe});
  final double fN2;
  final double fHe;
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

/// A cylinder available on the dive, with its precomputed MOD for the diver's
/// ppO2 ceiling. [maxPpO2Mod] is the deepest depth (m) where ppO2 <= ceiling.
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
}

/// Open-circuit optimal ascent: at each depth picks the eligible gas with the
/// highest O2 (ppO2 at depth <= [maxPpO2]). Eligibility is expressed as MOD on
/// [AvailableGas.maxPpO2Mod], derived once via O2ToxicityCalculator.calculateMod
/// so ppO2 is never re-derived here.
class OptimalOcAscentGas extends AscentGasPlan {
  OptimalOcAscentGas({required List<AvailableGas> gases, required this.maxPpO2})
    : assert(gases.isNotEmpty, 'OptimalOcAscentGas requires at least one gas'),
      _gases = List.unmodifiable(gases);

  final List<AvailableGas> _gases;
  final double maxPpO2;

  @override
  AscentGas gasForDepth(double depthMeters) {
    AvailableGas? best;
    for (final g in _gases) {
      // Eligible when at or above its MOD (depth <= MOD). A tiny tolerance keeps
      // the gas eligible exactly at its MOD despite float rounding.
      if (depthMeters <= g.maxPpO2Mod + 1e-9) {
        if (best == null || _prefer(g, best)) best = g;
      }
    }
    // The back gas is always in [_gases], so best is never null in practice;
    // fall back to the deepest-usable gas (smallest fO2) if it ever is.
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
}
