import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/density/density_slider.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/profile_override_caption.dart';

/// A ppO2 limit that defaults to the diver's profile value (issue #2342).
///
/// While it follows the profile the caption says so. Once moved away it is
/// marked as differing, with the profile value beside it and a way back.
class ModPpO2LimitSlider extends StatelessWidget {
  const ModPpO2LimitSlider({
    super.key,
    required this.label,
    required this.value,
    required this.profileValue,
    required this.isOverridden,
    required this.onChanged,
    required this.onReset,
    this.min = modLimitPpO2Min,
    this.max = modLimitPpO2Max,
    this.step = 0.05,
    this.fractionDigits = 2,
    this.icon = Icons.speed,
  });

  final String label;

  /// The value in effect: the override, or the profile value.
  final double value;
  final double profileValue;
  final bool isOverridden;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  /// Range and step; the ppO2 limits by default. The CCR setpoint uses its
  /// own range in 0.1 bar steps.
  final double min;
  final double max;
  final double step;
  final int fractionDigits;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DensitySlider(
          label: label,
          icon: icon,
          value: value,
          unit: ' bar',
          fractionDigits: fractionDigits,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
        ),
        ProfileOverrideCaption(
          isOverridden: isOverridden,
          profileValueText:
              '${formatFixedForDisplay(profileValue, fractionDigits)} bar',
          onReset: onReset,
        ),
      ],
    );
  }
}
