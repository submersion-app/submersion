import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/linked_incidents_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The safety review card and the linked-incidents chip, as one section.
///
/// Both halves collapse to nothing independently -- the review when
/// disabled, absent, or without findings; the chip when nothing links this
/// dive -- so the section as a whole must decide, before either half builds,
/// whether it has anything to show at all. That decision also picks which
/// half [topGap] belongs to: whichever renders first gets it, and the other,
/// if it also renders, gets the smaller gap that groups the two together.
class DiveSafetySummarySection extends ConsumerWidget {
  const DiveSafetySummarySection({
    super.key,
    required this.diveId,
    required this.hasProfile,
    required this.topGap,
  });

  final String diveId;

  /// Whether the dive has a profile to compute review findings from.
  ///
  /// A gauge or manually-logged dive has neither ascent rates nor a deco
  /// ceiling, so [SafetyReviewSection] never has anything to show for one;
  /// the incidents chip is unaffected.
  final bool hasProfile;

  /// Gap to place above whichever half renders first.
  final double topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final review = ref.watch(safetyReviewProvider(diveId)).value;
    final reviewHasContent =
        hasProfile && hasVisibleSafetyFindings(settings, review);

    final incidents = ref.watch(incidentsForDiveProvider(diveId)).value;
    final incidentsHasContent = incidents != null && incidents.isNotEmpty;

    if (!reviewHasContent && !incidentsHasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reviewHasContent) SafetyReviewSection(diveId: diveId),
          if (incidentsHasContent)
            Padding(
              padding: EdgeInsets.only(top: reviewHasContent ? 12 : 0),
              child: LinkedIncidentsRow(diveId: diveId),
            ),
        ],
      ),
    );
  }
}
