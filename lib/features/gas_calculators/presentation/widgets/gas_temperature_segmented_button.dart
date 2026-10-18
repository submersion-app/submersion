import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';

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
            label: Text(units.formatTemperature(option.celsius, decimals: 0)),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
