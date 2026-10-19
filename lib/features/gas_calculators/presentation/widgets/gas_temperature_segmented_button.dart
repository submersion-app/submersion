import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';

/// [temperature] in the diver's temperature unit, in whole degrees: the form
/// the toggle, the MOD density row and its assessment text all share.
String formatGasTemperature(
  UnitFormatter units,
  GasDensityTemperature temperature,
) => units.formatTemperature(temperature.celsius, decimals: 0);

/// The 0/20 C gas temperature toggle, shared by every calculator that lets
/// the diver pick the temperature a density check assumes.
class GasTemperatureSegmentedButton extends StatelessWidget {
  const GasTemperatureSegmentedButton({
    super.key,
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  final UnitFormatter units;
  final GasDensityTemperature selected;
  final ValueChanged<GasDensityTemperature> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GasDensityTemperature>(
      segments: [
        for (final option in GasDensityTemperature.values)
          ButtonSegment(
            value: option,
            label: Text(formatGasTemperature(units, option)),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
