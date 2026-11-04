import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Setup section named [key] as a setting group a series shares, or
/// null for a section it does not (CCR, gear, the DPV team).
PlanSettingGroup? settingGroupForSection(String key) {
  for (final group in PlanSettingGroup.values) {
    if (group.name == key) return group;
  }
  return null;
}

/// Under a Setup section's title in a series (issue #3565): whether the
/// selected dive's settings there are the series', taken from it, or its
/// own. Empty on a single dive.
class PlanSettingScopeLabel extends ConsumerWidget {
  const PlanSettingScopeLabel(this.group, {super.key});

  final PlanSettingGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(settingScopeProvider(group));
    if (scope == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (text, tooltip) = switch (scope) {
      SettingScope.series => (
        l10n.plannerSeries_scope_series,
        l10n.plannerSeries_scope_seriesHint,
      ),
      SettingScope.fromSeries => (l10n.plannerSeries_scope_fromSeries, null),
      SettingScope.thisDive => (l10n.plannerSeries_scope_thisDive, null),
    };
    final label = Text(
      text,
      key: ValueKey('settingScope_${group.name}'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scope == SettingScope.thisDive
            ? theme.colorScheme.tertiary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
    return tooltip == null ? label : Tooltip(message: tooltip, child: label);
  }
}

/// At the top of a Setup section whose settings a later dive has made its
/// own: put them back to the series', or make them the series'.
class PlanSettingScopeActions extends ConsumerWidget {
  const PlanSettingScopeActions(this.group, {super.key});

  final PlanSettingGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(settingScopeProvider(group)) != SettingScope.thisDive) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final series = ref.read(planSeriesNotifierProvider.notifier);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.undo, size: 18),
            label: Text(l10n.plannerSeries_scope_reset),
            onPressed: () => series.resetGroupToSeries(group),
          ),
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: Text(l10n.plannerSeries_scope_applyAll),
            onPressed: () => series.applyGroupToAll(group),
          ),
        ],
      ),
    );
  }
}
