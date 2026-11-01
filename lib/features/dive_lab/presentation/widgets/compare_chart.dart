import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';

/// The section's chart: the dive's profile with each line laid over it on one
/// time axis, zero at the dive's start. Read-only, since tapping it opens the
/// Compare page, which has the full chart.
class CompareChart extends StatelessWidget {
  const CompareChart({
    super.key,
    required this.profile,
    required this.overlays,
    required this.durationSeconds,
    this.decoStartSeconds,
  });

  final List<DiveProfilePoint> profile;
  final List<ChartSourceOverlay> overlays;

  /// The longest line's runtime, so no line runs off the axis.
  final int durationSeconds;

  /// Where the dive ran out of no-deco time, marked on the axis.
  final int? decoStartSeconds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: IgnorePointer(
        child: DiveProfileChart(
          profile: profile,
          diveDuration: Duration(seconds: durationSeconds),
          showTemperature: false,
          overlays: overlays,
          highlightedTimestamp: decoStartSeconds,
        ),
      ),
    );
  }
}
