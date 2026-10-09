/// Isobaric counterdiffusion (ICD) risk between two gases (issue #3121).
///
/// Compares the gas a diver breathes before a switch ("Gas A") against the
/// gas switched to ("Gas B") using the common "rule of fifths": the nitrogen
/// fraction may rise by at most a fifth of how much the helium fraction
/// falls. Mirrors Subsurface's `isobaric_counterdiffusion()` (`core/gas.c`):
/// without helium in the starting gas there is nothing to counterdiffuse
/// against, so the check never fires, whatever the new gas holds.
library;

/// How a gas switch reads against the rule of fifths.
enum IcdSeverity { ok, caution, violation }

/// One side of the comparison: a breathing gas, O2 and He in percent. The
/// nitrogen fraction is always the remainder, never entered directly.
class IcdGasInputs {
  final double o2Percent;
  final double hePercent;

  const IcdGasInputs({required this.o2Percent, required this.hePercent});

  double get n2Percent => 100.0 - o2Percent - hePercent;
}

class IcdInputs {
  final IcdGasInputs gasA;
  final IcdGasInputs gasB;

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
/// Subsurface's `5 * dN2 > -dHe`. Only evaluated when the starting gas
/// carries helium, helium actually falls, and nitrogen actually rises --
/// the same three guards as the reference implementation.
IcdResult computeIcd(IcdInputs inputs) {
  final n2A = inputs.gasA.n2Percent;
  final n2B = inputs.gasB.n2Percent;
  final heDecrease = inputs.gasA.hePercent - inputs.gasB.hePercent;
  final n2Increase = n2B - n2A;

  final applies = inputs.gasA.hePercent > 0 && heDecrease > 0 && n2Increase > 0;
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

/// Two ways to fix a flagged switch, each keeping one gas's O2 and He
/// exactly as entered and adjusting only the He of the other -- the pairing
/// the UI offers so a diver can pick whichever gas they are not free to
/// change (e.g. a fixed deco gas already blended).
class IcdFixSuggestions {
  /// He% for Gas B that keeps Gas A unchanged, clamped to 0..100-O2(B).
  final double heBKeepingGasA;

  /// He% for Gas A that keeps Gas B unchanged, clamped to 0..100-O2(A).
  final double heAKeepingGasB;

  const IcdFixSuggestions({
    required this.heBKeepingGasA,
    required this.heAKeepingGasB,
  });
}

/// Suggests, for each gas in turn, the He% the other gas would need so the
/// nitrogen fraction does not rise at all across the switch (N2 before
/// equals N2 after). That is stricter than the rule of fifths requires, but
/// simpler to reason about than finding the exact 1/5 boundary, and it always
/// resolves to [IcdSeverity.ok] once applied, within the valid He% range.
IcdFixSuggestions computeIcdFixSuggestions(IcdInputs inputs) {
  final a = inputs.gasA;
  final b = inputs.gasB;

  double clampHe(double he, double o2) => he.clamp(0.0, 100.0 - o2).toDouble();

  return IcdFixSuggestions(
    heBKeepingGasA: clampHe(
      a.hePercent + a.o2Percent - b.o2Percent,
      b.o2Percent,
    ),
    heAKeepingGasB: clampHe(
      b.hePercent + b.o2Percent - a.o2Percent,
      a.o2Percent,
    ),
  );
}
