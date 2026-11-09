import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/estimated_profile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/estimated_profile_chart.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive Profile card for a dive with no recorded profile: an outline
/// estimated from its depth and times (issue #4112).
///
/// Only the chart: the recorded card's toolbar (range, annotations, 3D,
/// fullscreen), sources bar and range statistics all work on samples this
/// dive does not have.
class DiveDetailEstimatedProfileSection extends StatelessWidget {
  const DiveDetailEstimatedProfileSection({super.key, required this.profile});

  final EstimatedProfile profile;

  /// The section for [dive], or null when it has a recorded profile or too
  /// little to estimate one from.
  static DiveDetailEstimatedProfileSection? forDive(Dive dive) {
    if (dive.profile.isNotEmpty) return null;
    final estimate = EstimatedProfile.estimate(
      maxDepth: dive.maxDepth,
      runtime: dive.measuredRuntime,
      bottomTime: dive.bottomTime,
    );
    if (estimate == null) return null;
    return DiveDetailEstimatedProfileSection(profile: estimate);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_detail_section_diveProfile,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            EstimatedProfileChart(profile: profile, height: 200),
          ],
        ),
      ),
    );
  }
}
