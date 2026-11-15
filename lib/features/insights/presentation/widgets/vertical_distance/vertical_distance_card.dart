import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// Total ascent and descent on Insights > Profile, drawn against mountains
/// and ocean depths (issue #4569).
///
/// The default card counts every metre each profile travelled. The
/// [VerticalDistanceCard.maxDepths] card draws the same scale counting each
/// dive straight down to its max depth and back.
class VerticalDistanceCard extends ConsumerWidget {
  const VerticalDistanceCard({super.key}) : maxDepthsOnly = false;

  const VerticalDistanceCard.maxDepths({super.key}) : maxDepthsOnly = true;

  /// True for the card that counts only each dive's max depth.
  final bool maxDepthsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<VerticalDistanceTimeline> timelineAsync = ref.watch(
      maxDepthsOnly
          ? maxDepthTimelineProvider
          : verticalDistanceTimelineProvider,
    );

    return StatSectionCard(
      title: maxDepthsOnly
          ? l10n.insights_profile_verticalDistance_maxDepthsTitle
          : l10n.insights_profile_verticalDistance_title,
      subtitle: maxDepthsOnly
          ? l10n.insights_profile_verticalDistance_maxDepthsSubtitle
          : l10n.insights_profile_verticalDistance_subtitle,
      info: (context) {
        final l10n = context.l10n;
        final units = infoUnits(context);
        return termsInfo(
          l10n,
          units,
          title: maxDepthsOnly
              ? l10n.insights_profile_verticalDistance_maxDepthsTitle
              : l10n.insights_profile_verticalDistance_title,
          summary: maxDepthsOnly
              ? l10n.info_insights_verticalDistance_maxDepthsSummary
              : l10n.info_insights_verticalDistance_summary(
                  units.formatDepthWhole(verticalDistanceDeadbandMeters),
                ),
        );
      },
      child: timelineAsync.when(
        data: (timeline) {
          if (timeline.isEmpty) {
            return StatEmptyState(
              icon: Icons.height,
              message: l10n.insights_profile_verticalDistance_empty,
            );
          }
          return VerticalDistanceScale(timeline: timeline);
        },
        loading: () => const SizedBox(
          height: kVerticalCardBodyHeight,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_profile_verticalDistance_error,
        ),
      ),
    );
  }
}
