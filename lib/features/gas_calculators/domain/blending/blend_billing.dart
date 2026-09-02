import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';

/// What one fill gas contributes to the bill.
class GasCostLine {
  const GasCostLine({
    required this.gas,
    required this.gasIndex,
    required this.addedBar,
    required this.freeGasLiters,
    required this.unitPricePer100,
    required this.cost,
  });

  final GasMix gas;

  /// Which configured bank this line charges, so the UI can label it against
  /// the same slot the price was entered under.
  ///
  /// Null only if a billable step reached costing without naming its bank,
  /// which [BlendStep.fillGasIndex] says cannot happen. It is nullable anyway
  /// because the cost of being wrong is a wrongly priced invoice, and an
  /// unpriced line is a far better failure than a confidently mispriced one.
  final int? gasIndex;

  /// Bar delivered for this gas, read at the fill temperature.
  final double addedBar;

  /// Free gas at the surface, in litres. Deliberately the ideal
  /// `water volume x bar`, see [computeBlendCost].
  final double freeGasLiters;

  /// Price per 100 litres, or null when the user has not priced this gas.
  final double? unitPricePer100;

  /// Null exactly when [unitPricePer100] is null.
  final double? cost;
}

class BillingResult {
  const BillingResult({required this.lines, required this.total});

  final List<GasCostLine> lines;

  /// Null when any line is unpriced, so a partial bill is never presented as
  /// a complete one.
  final double? total;
}

/// Price a fill procedure at [pricesPer100] per 100 litres of free gas, for a
/// cylinder of [waterLiters] water capacity.
///
/// The volume is the ideal `water volume x bar delivered`, regardless of which
/// equation of state the blend itself was solved with. That is on purpose: a
/// fill station meters by gauge pressure drop and charges for the pressure it
/// delivered, so the ideal figure is the commercial truth even where it is not
/// the physical one. Every line carries its [GasCostLine.addedBar] so the
/// arithmetic can be checked by hand against an invoice.
///
/// [pricesPer100] is indexed by CONFIGURED BANK, not by step order. A blend
/// that skips a bank (a helium-free target skips the helium source) would
/// otherwise charge the second gas it actually used at the second bank's
/// price, which is how air came to be billed at helium's rate (PR #1215
/// review). A short list, or a null entry, leaves that line unpriced and the
/// total null.
BillingResult computeBlendCost({
  required BlendResult blend,
  required double waterLiters,
  required List<double?> pricesPer100,
}) {
  final fills = blend.steps.where((s) => s.fillGas != null).toList();
  // No cylinder means nothing can be priced yet. Treating it as zero volume
  // produced a finished-looking bill reading 0.00, which is the same shape of
  // failure as a blank mix box meaning 0% (PR #1215 review).
  final priceable = waterLiters > 0;
  final volume = priceable ? waterLiters : 0.0;

  final lines = <GasCostLine>[];
  var total = 0.0;
  var complete = true;

  for (final step in fills) {
    final slot = step.fillGasIndex;
    // Defaulting a missing bank to 0 would quietly charge oxygen's rate for
    // whatever gas this actually is. Leaving it unpriced makes the total
    // report itself incomplete instead (PR #1215 review).
    assert(slot != null, 'a billable step must name the bank it drew from');
    final price = !priceable || slot == null || slot >= pricesPer100.length
        ? null
        : pricesPer100[slot];
    final liters = volume * step.addedBar;
    final cost = price == null ? null : liters / 100 * price;
    if (cost == null) {
      complete = false;
    } else {
      total += cost;
    }
    lines.add(
      GasCostLine(
        gas: step.fillGas!,
        gasIndex: slot,
        addedBar: step.addedBar,
        freeGasLiters: liters,
        unitPricePer100: price,
        cost: cost,
      ),
    );
  }

  return BillingResult(lines: lines, total: complete ? total : null);
}
