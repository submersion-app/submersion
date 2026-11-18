import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
  const VerticalDistanceCard({super.key, this.scaleExtentMeters})
    : maxDepthsOnly = false,
      keepNoteRow = true;

  const VerticalDistanceCard.maxDepths({
    super.key,
    this.scaleExtentMeters,
    this.keepNoteRow = false,
  }) : maxDepthsOnly = true;

  /// True for the card that counts only each dive's max depth. Its timeline
  /// never estimates a dive, so it has no estimated-dives note.
  final bool maxDepthsOnly;

  /// A height shared with the card beside it, so both draw on one scale;
  /// null for the card's own. See [VerticalDistanceScale.extentMeters].
  final double? scaleExtentMeters;

  /// Keeps the estimated-dives note's row even with no note to show. Always
  /// for the default card, whose height must not jump when its note appears
  /// or between loading and loaded; for the max depths card only beside a
  /// card that has the row, so the two end level.
  final bool keepNoteRow;

  String _title(AppLocalizations l10n) => maxDepthsOnly
      ? l10n.insights_profile_verticalDistance_maxDepthsTitle
      : l10n.insights_profile_verticalDistance_title;

  String _subtitle(AppLocalizations l10n) => maxDepthsOnly
      ? l10n.insights_profile_verticalDistance_maxDepthsSubtitle
      : l10n.insights_profile_verticalDistance_subtitle;

  String _summary(AppLocalizations l10n, UnitFormatter units) => maxDepthsOnly
      ? l10n.info_insights_verticalDistance_maxDepthsSummary
      : l10n.info_insights_verticalDistance_summary(
          units.formatDepthWhole(verticalDistanceDeadbandMeters),
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<VerticalDistanceTimeline> timelineAsync = ref.watch(
      maxDepthsOnly
          ? maxDepthTimelineProvider
          : verticalDistanceTimelineProvider,
    );

    return StatSectionCard(
      title: _title(l10n),
      subtitle: _subtitle(l10n),
      info: (context) {
        final l10n = context.l10n;
        final units = infoUnits(context);
        return termsInfo(
          l10n,
          units,
          title: _title(l10n),
          summary: _summary(l10n, units),
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
          return VerticalDistanceScale(
            timeline: timeline,
            reservesNote: keepNoteRow,
            extentMeters: scaleExtentMeters,
          );
        },
        loading: () => SizedBox(
          height: keepNoteRow
              ? kVerticalCardBodyHeight
              : kVerticalScaleAndStripHeight,
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_profile_verticalDistance_error,
        ),
      ),
    );
  }
}
