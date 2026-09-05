// A flush/purge fee for clearing the fill hose before drawing a gas.
//
// Priced from BlenderPreferences.gasPrices, keyed by the same BlenderGasRole
// as the fill banks (issue #42): a hose only needs purging for the gas
// actually connected to it, and now that a bank's role is a fixed identity
// rather than a position, the price already entered for that role's bank is
// the flush fee's price too. There is no separate flush-fee price to enter or
// drift out of sync with it.

import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';

/// How often the configured flush fee appears on the bill.
enum FlushFeeMode {
  /// Once per billing session, regardless of how many fills were saved. A
  /// hose is purged once when a gas source is connected, not on every fill
  /// drawn from it afterwards.
  perInvoice,

  /// Once for every fill saved to the bill.
  perFill;

  static FlushFeeMode fromName(String? name) => switch (name) {
    'perFill' => FlushFeeMode.perFill,
    _ => FlushFeeMode.perInvoice,
  };
}

/// One role's flush-fee configuration: the volume purged for it.
///
/// [volumeLiters] is a starting point, not a fixed amount: the invoice line
/// it seeds stays independently editable, the same way [BilledFill.total]
/// stays editable apart from [BilledFill.lines]. The price to purge at is not
/// stored here; it is read from [BlenderPreferences.gasPrices] for the same
/// [BlenderGasRole], so there is one price per role rather than two.
class FlushFeeGasSetting {
  const FlushFeeGasSetting({required this.volumeLiters});

  final double volumeLiters;

  FlushFeeGasSetting copyWith({double? volumeLiters}) =>
      FlushFeeGasSetting(volumeLiters: volumeLiters ?? this.volumeLiters);

  Map<String, dynamic> toJson() => {'volumeLiters': volumeLiters};

  static FlushFeeGasSetting fromJson(
    Object? json, {
    required double defaultVolumeLiters,
  }) {
    if (json is! Map) {
      return FlushFeeGasSetting(volumeLiters: defaultVolumeLiters);
    }
    return FlushFeeGasSetting(
      volumeLiters: _toDouble(json['volumeLiters']) ?? defaultVolumeLiters,
    );
  }
}

/// The default per-role settings a fresh install starts with: enough to
/// purge a hose. One entry per [BlenderGasRole], in that enum's order.
const List<FlushFeeGasSetting> defaultFlushFeeGases = [
  FlushFeeGasSetting(volumeLiters: 20),
  FlushFeeGasSetting(volumeLiters: 20),
  FlushFeeGasSetting(volumeLiters: 20),
];

/// What one role's flush fee costs for [volumeLiters] at [pricePer100], or
/// null when that role's bank has not been priced.
double? flushFeeCost(double volumeLiters, double? pricePer100) =>
    pricePer100 == null ? null : volumeLiters / 100 * pricePer100;

double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

/// How many times the configured fee appears on a bill holding [fillCount]
/// fills. Zero under [FlushFeeMode.perFill] before anything has been filled:
/// there is no fill to purge for yet.
int flushFeeMultiplier({required FlushFeeMode mode, required int fillCount}) =>
    mode == FlushFeeMode.perInvoice ? 1 : fillCount;

/// The flush fee as billable lines, one per role, so every surface that
/// totals, archives or exports a bill itemises the fee instead of folding it
/// into a total nothing on the page accounts for.
///
/// Derived on demand rather than appended to the running bill: the fee
/// reprices itself whenever its settings change, and under
/// [FlushFeeMode.perFill] whenever another cylinder is billed, so it cannot
/// be a stored row the way a finished fill is. Materialising it at the moment
/// a bill is totalled, paid or exported is what keeps those three agreeing on
/// one number.
///
/// [labelFor] supplies the role's display name, keeping l10n and
/// BuildContext out of the domain. A line carries no [BilledFill.lines]: the
/// volume and price behind its amount are settings, not gas drawn from a
/// bank, and there is nothing to itemise beneath it.
List<BilledFill> flushFeeFills({
  required bool enabled,
  required FlushFeeMode mode,
  required int fillCount,
  required List<FlushFeeGasSetting> gases,
  required List<double?> pricesPer100,
  required String Function(BlenderGasRole role) labelFor,
}) {
  final multiplier = flushFeeMultiplier(mode: mode, fillCount: fillCount);
  if (!enabled || multiplier < 1) return const [];
  return [
    for (final role in BlenderGasRole.values)
      if (role.index < gases.length)
        BilledFill(
          id: 'flush-${role.name}',
          label: multiplier > 1
              ? '${labelFor(role)}  \u00d7$multiplier'
              : labelFor(role),
          lines: const [],
          total: flushFeeCost(
            gases[role.index].volumeLiters * multiplier,
            role.index < pricesPer100.length ? pricesPer100[role.index] : null,
          ),
        ),
  ];
}
