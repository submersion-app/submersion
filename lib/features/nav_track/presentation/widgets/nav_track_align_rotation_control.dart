import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/presentation/widgets/nav_track_stepper_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The rotation control: a 0.5 degree stepper and field. Clamped to +/-180
/// degrees: the same range a diver could reach one step at a time is
/// unbounded in principle, but a rotation outside it is never meaningful (it
/// is equivalent to a smaller rotation the other way), so that is the
/// sensible bound for typed input.
class NavTrackRotationControl extends StatelessWidget {
  const NavTrackRotationControl({
    super.key,
    required this.headingOffsetDeg,
    required this.onChanged,
  });

  final double headingOffsetDeg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => NavTrackStepperField(
    label: context.l10n.navTrack_align_rotationLabel,
    value: headingOffsetDeg,
    min: -180,
    max: 180,
    step: 0.5,
    suffix: '°',
    downKey: 'nav-track-align-rotate-down',
    fieldKey: 'nav-track-align-rotation-field',
    upKey: 'nav-track-align-rotate-up',
    onChanged: onChanged,
  );
}
