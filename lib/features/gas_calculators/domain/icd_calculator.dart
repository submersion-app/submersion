/// Isobaric counterdiffusion (ICD) risk between two gases (issue #3121).
///
/// Compares the gas a diver breathes before a switch ("Gas A") against the
/// gas switched to ("Gas B") using the common "rule of fifths": the nitrogen
/// fraction may rise by at most a fifth of how much the helium fraction
/// falls. Mirrors Subsurface's `isobaric_counterdiffusion()` (`core/gas.c`):
/// without helium in the starting gas there is nothing to counterdiffuse
/// against, so the check never fires, whatever the new gas holds.
library;

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// How a gas switch reads against the rule of fifths.
enum IcdSeverity { ok, caution, violation }

/// The two sides of the comparison. Each is a plain [GasMix], O2 and He in
/// percent, with nitrogen always the remainder.
class IcdInputs {
  final GasMix gasA;
  final GasMix gasB;

  const IcdInputs({required this.gasA, required this.gasB});
}

class IcdResult {
  final double n2PercentA;
  final double n2PercentB;

  /// How much the helium fraction falls from A to B. Negative when it rises.
  final double heDecreasePercent;

  /// How much the nitrogen fraction rises from A to B. Negative when it falls.
  final double n2IncreasePercent;

  /// The largest nitrogen increase the rule of fifths allows, given
  /// [heDecreasePercent]. Zero whenever the rule does not apply.
  final double maxAllowedN2IncreasePercent;

  final IcdSeverity severity;

  const IcdResult({
    required this.n2PercentA,
    required this.n2PercentB,
    required this.heDecreasePercent,
    required this.n2IncreasePercent,
    required this.maxAllowedN2IncreasePercent,
    required this.severity,
  });
}

/// Below this fraction of the allowed increase the result reads as
/// [IcdSeverity.ok] rather than [IcdSeverity.caution], so a comfortable
/// margin stays green instead of flipping to amber right at the edge.
const double icdCautionThreshold = 0.8;

/// Rule of fifths: `5 * n2Increase > heDecrease` is a violation, matching
/// Subsurface's `5 * dN2 > -dHe`. Only evaluated when helium actually falls
/// and nitrogen actually rises. Subsurface's third guard, helium in the
/// starting gas, needs no check of its own: Gas B never holds negative
/// helium, so a falling helium fraction already means Gas A carries some.
IcdResult computeIcd(IcdInputs inputs) {
  final n2A = inputs.gasA.n2;
  final n2B = inputs.gasB.n2;
  final heDecrease = inputs.gasA.he - inputs.gasB.he;
  final n2Increase = n2B - n2A;

  final applies = heDecrease > 0 && n2Increase > 0;
  final maxAllowed = applies ? heDecrease / 5.0 : 0.0;

  final severity = !applies
      ? IcdSeverity.ok
      : n2Increase > maxAllowed
      ? IcdSeverity.violation
      : n2Increase > maxAllowed * icdCautionThreshold
      ? IcdSeverity.caution
      : IcdSeverity.ok;

  return IcdResult(
    n2PercentA: n2A,
    n2PercentB: n2B,
    heDecreasePercent: heDecrease,
    n2IncreasePercent: n2Increase,
    maxAllowedN2IncreasePercent: maxAllowed,
    severity: severity,
  );
}

/// One way to fix a flagged switch: the percent value to set, and whether
/// applying it -- keeping everything else as entered -- actually brings the
/// switch out of [IcdSeverity.violation] (into [IcdSeverity.ok] or
/// [IcdSeverity.caution] -- the widget itself treats a caution as already
/// compliant, so a suggestion that only gets that far still counts as
/// resolving). A suggestion can fail to resolve when its value gets clamped
/// to the valid 0..100 range: clamping a He-based suggestion to 0 always
/// disables the rule itself (no helium left to counterdiffuse against), so
/// those always resolve; clamping an O2-based suggestion leaves He
/// untouched, so the rule can still fire afterwards.
class IcdFixSuggestion {
  final double value;
  final bool resolves;

  const IcdFixSuggestion({required this.value, required this.resolves});
}

/// Four ways to fix a flagged switch: for each gas (A and B), the He% or the
/// O2% the *other* gas would need so the nitrogen fraction does not rise at
/// all across the switch (N2 before equals N2 after). That is stricter than
/// the rule of fifths requires, but simpler to reason about than finding the
/// exact 1/5 boundary. The UI groups them by gas, so a diver can pick
/// whichever gas they are not free to change (e.g. a fixed deco gas already
/// blended) and whichever property (He or O2) they would rather adjust.
class IcdFixSuggestions {
  /// He% for Gas B that keeps Gas A unchanged.
  final IcdFixSuggestion heBKeepingGasA;

  /// He% for Gas A that keeps Gas B unchanged.
  final IcdFixSuggestion heAKeepingGasB;

  /// O2% for Gas A that keeps Gas B unchanged.
  final IcdFixSuggestion o2AKeepingGasB;

  /// O2% for Gas B that keeps Gas A unchanged.
  final IcdFixSuggestion o2BKeepingGasA;

  const IcdFixSuggestions({
    required this.heBKeepingGasA,
    required this.heAKeepingGasB,
    required this.o2AKeepingGasB,
    required this.o2BKeepingGasA,
  });
}

IcdFixSuggestions computeIcdFixSuggestions(IcdInputs inputs) {
  final a = inputs.gasA;
  final b = inputs.gasB;

  double clamp(double value, double other) =>
      value.clamp(0.0, 100.0 - other).toDouble();

  bool resolvesAsGasA(GasMix adjusted) =>
      computeIcd(IcdInputs(gasA: adjusted, gasB: b)).severity !=
      IcdSeverity.violation;
  bool resolvesAsGasB(GasMix adjusted) =>
      computeIcd(IcdInputs(gasA: a, gasB: adjusted)).severity !=
      IcdSeverity.violation;

  final heA = clamp(b.he + b.o2 - a.o2, a.o2);
  final heAMix = GasMix(o2: a.o2, he: heA);
  final heB = clamp(a.he + a.o2 - b.o2, b.o2);
  final heBMix = GasMix(o2: b.o2, he: heB);
  final o2A = clamp(b.o2 + b.he - a.he, a.he);
  final o2AMix = GasMix(o2: o2A, he: a.he);
  final o2B = clamp(a.o2 + a.he - b.he, b.he);
  final o2BMix = GasMix(o2: o2B, he: b.he);

  return IcdFixSuggestions(
    heBKeepingGasA: IcdFixSuggestion(
      value: heB,
      resolves: resolvesAsGasB(heBMix),
    ),
    heAKeepingGasB: IcdFixSuggestion(
      value: heA,
      resolves: resolvesAsGasA(heAMix),
    ),
    o2AKeepingGasB: IcdFixSuggestion(
      value: o2A,
      resolves: resolvesAsGasA(o2AMix),
    ),
    o2BKeepingGasA: IcdFixSuggestion(
      value: o2B,
      resolves: resolvesAsGasB(o2BMix),
    ),
  );
}
