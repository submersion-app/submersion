import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/insights/presentation/providers/my_role_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/distribution_bar_row.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dives per role the diver held (issue #4409), with Not set as its own
/// bar. A dive with several roles counts under each, so there is no pie:
/// the bars are not shares of one total, as on the dive types list.
class MyRoleCard extends ConsumerWidget {
  const MyRoleCard({super.key, this.onOpen});

  /// Opens the dives behind a bar: its key (a role id or
  /// [kNotRecordedDistributionKey]) and its label. Defaults to the dive
  /// list, narrowed from the Insights filter by [diverRoleDivesFilter].
  final void Function(String key, String label)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // `value`, not `valueOrNull`: a dive_roles write reloads the map, and
    // the bars keep their names until the new one lands.
    final roles = ref.watch(diveRoleMapProvider);
    final rolesById = roles.value ?? const <String, DiveRole>{};
    // Until the map's first load the bars wait, so none shows a raw id; a
    // failed load still draws them, under synthetic names.
    final namesPending = roles.isLoading && !roles.hasValue;
    const loading = SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
    String labelFor(String key) => key == kNotRecordedDistributionKey
        ? l10n.insights_social_myRole_notSet
        : (rolesById[key] ?? DiveRole.synthetic(key)).localizedName(l10n);
    void open(String key) {
      final label = labelFor(key);
      final custom = onOpen;
      if (custom != null) return custom(key, label);
      openFilteredChartDives(
        context,
        ref,
        chart: l10n.insights_social_myRole_title,
        row: label,
        narrow: (scope) => diverRoleDivesFilter(scope, key),
      );
    }

    return StatSectionCard(
      title: l10n.insights_social_myRole_title,
      subtitle: l10n.insights_social_myRole_subtitle,
      child: ref
          .watch(diverRoleDistributionProvider)
          .when(
            data: (segments) {
              if (segments.isEmpty) {
                return StatEmptyState(
                  icon: Icons.badge_outlined,
                  message: l10n.insights_social_myRole_empty,
                );
              }
              if (namesPending) return loading;
              final maxCount = segments
                  .map((s) => s.count)
                  .reduce((a, b) => a > b ? a : b);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, segment) in segments.indexed)
                    DistributionBarRow(
                      label: labelFor(segment.label),
                      count: segment.count,
                      totalDurationSeconds: segment.totalDurationSeconds,
                      color: segment.label == kNotRecordedDistributionKey
                          ? Colors.grey.shade500
                          : kDistributionBarColors[index %
                                kDistributionBarColors.length],
                      fraction: segment.count / maxCount,
                      fillKey: ValueKey('my-role-bar-fill-${segment.label}'),
                      onTap: () => open(segment.label),
                    ),
                ],
              );
            },
            loading: () => loading,
            error: (_, _) => StatEmptyState(
              icon: Icons.error_outline,
              message: l10n.insights_social_myRole_error,
            ),
          ),
    );
  }
}
