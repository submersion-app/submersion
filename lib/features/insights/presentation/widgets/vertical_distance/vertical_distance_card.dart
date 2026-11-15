import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance.dart';
import 'package:submersion/features/insights/presentation/providers/vertical_distance_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/insights/presentation/widgets/vertical_distance/vertical_distance_scale.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// Total ascent and descent on Insights > Profile, drawn against mountains
/// and ocean depths (issue #4569).
class VerticalDistanceCard extends ConsumerWidget {
  const VerticalDistanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final timelineAsync = ref.watch(verticalDistanceTimelineProvider);

    return StatSectionCard(
      title: l10n.insights_profile_verticalDistance_title,
      subtitle: l10n.insights_profile_verticalDistance_subtitle,
      info: (context) {
        final units = infoUnits(context);
        return termsInfo(
          context.l10n,
          units,
          title: context.l10n.insights_profile_verticalDistance_title,
          summary: context.l10n.info_insights_verticalDistance_summary(
            units.formatDepth(verticalDistanceDeadbandMeters, decimals: 0),
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
          height: kVerticalScaleHeight + 56,
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
