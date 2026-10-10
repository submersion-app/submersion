import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_card_parts.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Water movement group of the Conditions tab (issue #3118): current
/// strength, current direction and swell height. Hidden when none of them is
/// recorded on any dive in the filter.
class WaterMovementGroup extends ConsumerWidget {
  const WaterMovementGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = l10n.insights_conditions_group_waterMovement;
    return ref
        .watch(conditionsStatsProvider)
        .when(
          // A background re-query (sync, download, unit switch) keeps the
          // cards; a spinner would shrink the page and lose the scroll.
          skipLoadingOnReload: true,
          loading: () => ConditionsGroupStatus(title: title, failed: false),
          error: (_, _) => ConditionsGroupStatus(title: title, failed: true),
          data: (stats) {
            if (stats.currentStrength.isEmpty &&
                stats.currentDirection.isEmpty &&
                stats.swellHeight.isEmpty) {
              return const SizedBox.shrink();
            }
            final units = UnitFormatter(ref.watch(settingsProvider));
            final total = stats.totalDives;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConditionsGroupHeader(title: title),
                ConditionsCategoryCard<CurrentStrength>(
                  title: l10n.insights_conditions_currentStrength_title,
                  subtitle: l10n.insights_conditions_currentStrength_subtitle,
                  stat: stats.currentStrength,
                  totalDives: total,
                  labelOf: (v) => v.localizedName(l10n),
                  kind: ConditionsChartKind.pie,
                  colorOf: _strengthColor,
                ),
                ConditionsCategoryCard<CurrentDirection>(
                  title: l10n.insights_conditions_currentDirection_title,
                  subtitle: l10n.insights_conditions_currentDirection_subtitle,
                  stat: stats.currentDirection,
                  totalDives: total,
                  labelOf: (v) => v.localizedName(l10n),
                  kind: ConditionsChartKind.bar,
                  barColor: Colors.teal.shade400,
                ),
                ConditionsBandCard(
                  title: l10n.insights_conditions_swellHeight_title,
                  subtitle: l10n.insights_conditions_swellHeight_subtitle,
                  stat: stats.swellHeight,
                  totalDives: total,
                  unitSymbol: units.depthSymbol,
                  barColor: Colors.blue.shade400,
                ),
              ],
            );
          },
        );
  }

  /// Calm to strong, cool to warm, keyed by value.
  static Color _strengthColor(CurrentStrength value) => switch (value) {
    CurrentStrength.none => Colors.green.shade300,
    CurrentStrength.light => Colors.lightBlue.shade300,
    CurrentStrength.moderate => Colors.orange.shade400,
    CurrentStrength.strong => Colors.red.shade400,
  };
}
