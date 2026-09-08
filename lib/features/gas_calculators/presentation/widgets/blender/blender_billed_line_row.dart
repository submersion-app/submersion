import 'package:flutter/material.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';

/// One gas/volume/cost row of an itemised fill, shared by the running bill
/// ([BlenderInvoiceCard]) and the read-only archive detail view: both show
/// exactly the same three columns, and a second copy of the volume-vs-pressure
/// fallback in the archive view is how that logic would drift out of step
/// with the running bill's (see [BilledGasLine.freeGasLiters]).
class BlenderBilledLineRow extends StatelessWidget {
  const BlenderBilledLineRow({
    super.key,
    required this.line,
    required this.currency,
    required this.units,
    required this.decimals,
  });

  final BilledGasLine line;
  final String currency;
  final UnitFormatter units;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(line.gas, style: style)),
          Expanded(
            flex: 4,
            child: Text(
              // Volume when this line has one (every fill saved since
              // #1335); pressure-only rows saved before that fall back,
              // since their volume was never kept.
              line.freeGasLiters != null
                  ? units.formatVolume(line.freeGasLiters)
                  : units.formatPressure(line.addedBar, decimals: decimals),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              line.cost == null ? '' : formatMoney(line.cost!, currency),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
