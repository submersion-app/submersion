import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart'
    show endLimitOverrideMaxMeters, endLimitOverrideMinMeters;
import 'package:submersion/features/gas_calculators/presentation/widgets/profile_override_caption.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// The END limit, overridable per diver like the ppO2 limits (issue #3112).
/// Tec modes only; Rec keeps reading the profile's END limit live.
class BestMixEndLimitSlider extends StatelessWidget {
  const BestMixEndLimitSlider({
    super.key,
    required this.label,
    required this.value,
    required this.profileValueMeters,
    required this.isOverridden,
    required this.units,
    required this.onChanged,
    required this.onReset,
  });

  final String label;
  final double value;
  final double profileValueMeters;
  final bool isOverridden;
  final UnitFormatter units;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final axis = UnitAxis.depthRange(
      units,
      minMeters: endLimitOverrideMinMeters,
      maxMeters: endLimitOverrideMaxMeters,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UnitSlider(
          icon: Icons.vertical_align_bottom,
          label: label,
          value: value,
          axis: axis,
          // In feet the 5 ft grid rarely lands on the profile value (30 m is
          // 98.4 ft), so the stop nearest it counts as following the profile;
          // otherwise any drag would leave an override the slider cannot undo.
          onChanged: (meters) =>
              (axis.toDisplay(meters) - axis.toDisplay(profileValueMeters))
                      .abs() <
                  axis.step / 2
              ? onReset()
              : onChanged(meters),
        ),
        ProfileOverrideCaption(
          isOverridden: isOverridden,
          profileValueText: units.formatDepth(profileValueMeters, decimals: 0),
          onReset: onReset,
        ),
      ],
    );
  }
}
