import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_stepper_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The scale control: a 1% stepper and field over
/// [NavTrackCorrection.scaleFactor], shown to the diver as a percentage.
class NavTrackScaleControl extends StatelessWidget {
  const NavTrackScaleControl({
    super.key,
    required this.scaleFactor,
    required this.onChanged,
  });

  final double scaleFactor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => NavTrackStepperField(
    label: context.l10n.navTrack_align_scaleLabel,
    // To 0.1%, so floating point noise from the factor never reaches the
    // field or a step.
    value: (scaleFactor * 1000).round() / 10,
    min: NavTrackCorrection.minScaleFactor * 100,
    max: NavTrackCorrection.maxScaleFactor * 100,
    step: 1,
    suffix: '%',
    fieldWidth: 104,
    downKey: 'nav-track-align-scale-down',
    fieldKey: 'nav-track-align-scale-field',
    upKey: 'nav-track-align-scale-up',
    onChanged: (percent) => onChanged((percent * 10).round() / 1000),
  );
}
