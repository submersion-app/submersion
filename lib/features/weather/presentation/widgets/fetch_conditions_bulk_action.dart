import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/features/weather/presentation/widgets/fetch_conditions_flow.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// "Fetch Conditions" for the dive list's selection bar (issue #4329): fills
/// missing weather on the checked dives from the historical archive, never
/// overwriting anything already recorded.
///
/// Runs the same flow as the logbook-wide menu entry, scoped to [selected].
/// The flow's outcome decides whether selection mode ends, so a diver who
/// backs out, or whose selection had nothing to fill, keeps their selection.
BulkAction fetchConditionsBulkAction(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> Function() selected,
}) => BulkAction(
  id: 'fetch_conditions',
  icon: Icons.cloud_download_outlined,
  label: context.l10n.diveLog_selection_tooltip_fetchConditions,
  onInvoke: () => showFetchConditionsFlow(
    context: context,
    service: ref.read(bulkConditionsServiceProvider),
    diveIds: selected(),
  ),
);
