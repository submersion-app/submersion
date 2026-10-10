import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/formatters/altitude_group_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The stats to chart, or null while loading or after a failed query.
///
/// `.value` alone would keep the previous data after a failed re-query, so
/// these cards would show stale counts beside the weather groups' error.
ConditionsStats? _currentStats(WidgetRef ref) {
  final stats = ref.watch(conditionsStatsProvider);
  return stats.hasError ? null : stats.value;
}

/// Dives per altitude group, in the Site & access group (issue #3118).
///
/// Renders nothing while loading or on failure: the weather groups above
/// already report the shared query's state, and this group's header stays
/// for the site type and entry method cards.
class AltitudeConditionsCard extends ConsumerWidget {
  const AltitudeConditionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _currentStats(ref);
    if (stats == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ConditionsCategoryCard<AltitudeGroup>(
      title: l10n.insights_conditions_altitude_title,
      subtitle: l10n.insights_conditions_altitude_subtitle,
      stat: stats.altitude,
      totalDives: stats.totalDives,
      labelOf: (v) => v.localizedName(l10n),
      kind: ConditionsChartKind.bar,
      barColor: Colors.brown.shade300,
    );
  }
}

/// Dives per exit method, in the Site & access group (issue #3118). The
/// stored value only: exit method has no site fallback.
class ExitMethodConditionsCard extends ConsumerWidget {
  const ExitMethodConditionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _currentStats(ref);
    if (stats == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ConditionsCategoryCard<EntryMethod>(
      title: l10n.insights_conditions_exitMethod_title,
      subtitle: l10n.insights_conditions_exitMethod_subtitle,
      stat: stats.exitMethod,
      totalDives: stats.totalDives,
      labelOf: (v) => v.localizedName(l10n),
      kind: ConditionsChartKind.bar,
      barColor: Colors.teal,
    );
  }
}
