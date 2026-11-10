import 'package:flutter/material.dart';

import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_input_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_result_card.dart';

/// Gas density calculator.
///
/// Density in g/L of the breathed gas at a target depth, for a trimix on
/// open circuit or as the diluent of a CCR loop at a setpoint, at a gas
/// temperature of 0 C or 20 C, in salt or fresh water.
class DensityCalculator extends StatelessWidget {
  const DensityCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DensityInputCard(),
              SizedBox(height: 16),
              DensityResultCard(),
            ],
          ),
        ),
      ),
    );
  }
}
