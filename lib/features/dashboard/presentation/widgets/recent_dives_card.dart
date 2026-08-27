import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width at which the card splits into list plus profile preview.
///
/// The list half is pinned to [kMasterPaneWidth]; the rest has to leave the
/// chart enough room to be worth reading, so the preview gets at least ~320px
/// plus the gap before the split is allowed.
const double _splitMinWidth = kMasterPaneWidth + 12 + 320;

/// Height of the profile preview. Roughly the height of three detailed dive
/// cards, so the two halves of the split read as one block at the default
/// three recent dives.
const double _previewHeight = 300;

/// A section showing recent dives with the same tile format as the dive list
class RecentDivesCard extends ConsumerWidget {
  const RecentDivesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentDivesAsync = ref.watch(recentDivesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with padding to match the card margins
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.l10n.dashboard_recentDives_sectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Tooltip(
                message: context.l10n.dashboard_recentDives_viewAllTooltip,
                child: TextButton(
                  onPressed: () => context.go('/dives'),
                  child: Text(context.l10n.dashboard_recentDives_viewAll),
                ),
              ),
            ],
          ),
        ),
        recentDivesAsync.when(
          data: (dives) {
            if (dives.isEmpty) {
              return _buildEmptyState(context);
            }

            // Calculate value range for card coloring based on active attribute
            final settings = ref.read(settingsProvider);
            final colorAttribute = settings.cardColorAttribute;
            final colorValues = dives
                .map((d) => getCardColorValueFromDive(d, colorAttribute))
                .whereType<double>();
            final minValue = colorValues.isNotEmpty
                ? colorValues.reduce((a, b) => a < b ? a : b)
                : null;
            final maxValue = colorValues.isNotEmpty
                ? colorValues.reduce((a, b) => a > b ? a : b)
                : null;
            final gradientColors = resolveGradientColors(
              presetName: settings.cardColorGradientPreset,
              customStart: settings.cardColorGradientStart,
              customEnd: settings.cardColorGradientEnd,
            );

            // Built once for the whole list rather than per row.
            final diveTypeLabelResolver = watchDiveTypeLabelResolver(
              ref,
              context.l10n,
            );

            final list = Column(
              children: dives.asMap().entries.map((entry) {
                final index = entry.key;
                final dive = entry.value;
                // Render through the shared DiveListItem so Recent dives honour
                // the same view-mode and card configuration as the Dives tab
                // (issue #506). The full Dive is passed for configurable extra
                // fields; the summary drives title/date/stat slots.
                return DiveListItem(
                  summary: DiveSummary.fromDive(dive),
                  diveTypeLabelResolver: diveTypeLabelResolver,
                  fullDive: dive,
                  diveNumber: dive.diveNumber ?? index + 1,
                  colorValue: getCardColorValueFromDive(dive, colorAttribute),
                  minValueInList: minValue,
                  maxValueInList: maxValue,
                  gradientStartColor: gradientColors.start,
                  gradientEndColor: gradientColors.end,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  onTap: () => context.push('/dives/${dive.id}'),
                );
              }).toList(),
            );

            // Measured against the card's own constraints, not the window:
            // this card is often the lead of a LeadSideGroup and so gets two
            // thirds of the width, and MediaQuery would not know that.
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < _splitMinWidth) return list;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pinned to the width a dive card has on the Dives page,
                    // where the list is the fixed-width master pane of a split
                    // view. Without this the shared DiveListItem gets
                    // stretched by the Expanded below and the same card
                    // renders at two noticeably different widths.
                    SizedBox(width: kMasterPaneWidth, child: list),
                    const SizedBox(width: 12),
                    // A fixed height rather than stretching to match the list.
                    // Stretching needs IntrinsicHeight, and that cannot
                    // measure this subtree: both the dive tiles and fl_chart
                    // use LayoutBuilder, which refuses intrinsic queries.
                    const Expanded(
                      child: SizedBox(
                        height: _previewHeight,
                        child: RecentDiveProfilePreview(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Semantics(
            label: context.l10n.dashboard_semantics_errorLoadingRecentDives,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.dashboard_recentDives_errorLoading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.waves_outlined,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.dashboard_recentDives_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showAddDiveBottomSheet(
                context: context,
                onLogManually: () => context.push('/dives/new'),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.dashboard_recentDives_logFirst),
            ),
          ],
        ),
      ),
    );
  }
}
