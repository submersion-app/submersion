import 'package:flutter/material.dart';

import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_assessment_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_depth_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_input_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_limits_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod/mod_result_card.dart';

/// Maximum Operating Depth (MOD) calculator.
///
/// Three modes (issue #2342): Rec for nitrox, OC Tec for trimix on open
/// circuit, CCR Tec for a diluent on a rebreather loop. Each gives the MOD,
/// rounded down, and assesses the gas at the MOD and at an optional target
/// depth. The inputs are saved like the blender's preferences.
class ModCalculator extends StatelessWidget {
  const ModCalculator({super.key});

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
              ModInputCard(),
              SizedBox(height: 16),
              ModLimitsCard(),
              SizedBox(height: 16),
              ModResultCard(),
              SizedBox(height: 16),
              ModAssessmentCard(),
              SizedBox(height: 16),
              ModDepthCard(),
            ],
          ),
        ),
      ),
    );
  }
}
