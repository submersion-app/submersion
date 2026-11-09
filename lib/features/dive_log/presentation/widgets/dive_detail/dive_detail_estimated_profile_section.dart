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

  /// The section for [dive], or null when [EstimatedProfile.forDive] has no
  /// outline for it.
  ///
  /// [hasStoredSeries] is `diveHasProfileSeriesProvider`'s answer.
  static DiveDetailEstimatedProfileSection? forDive(
    Dive dive, {
    required bool? hasStoredSeries,
  }) {
    final estimate = EstimatedProfile.forDive(
      dive,
      hasStoredSeries: hasStoredSeries,
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
