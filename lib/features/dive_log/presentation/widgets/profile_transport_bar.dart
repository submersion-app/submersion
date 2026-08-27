import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';

/// The bottom strip of the fullscreen profile view: playback transport only.
///
/// Phone layouts omit this bar entirely so the chart gets the whole screen
/// (#811). The metric readouts it used to carry duplicated the draggable
/// readout card that floats over the chart.
class ProfileTransportBar extends StatelessWidget {
  final String diveId;

  /// The profile the chart renders; the scrub slider paints its minimap
  /// from these points and seeks within their timestamp range.
  final List<DiveProfilePoint> profile;

  const ProfileTransportBar({
    super.key,
    required this.diveId,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: ProfileTransportControls(diveId: diveId, profile: profile),
    );
  }
}
