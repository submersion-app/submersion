import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('OpenChartDives');

/// Resolves the dives one number on a chart counted, under the Insights
/// filter [scope] and the current diver.
typedef ChartDiveIdsLoader =
    Future<List<String>> Function(
      InsightsRepository repository,
      String? diverId,
      DiveFilterState scope,
    );

/// Opens the dive list on the dives behind [row] of the chart titled [chart]
/// (issue #3805).
///
/// The list gets those ids and nothing else, so it holds exactly the dives
/// the number counted: excluded and planned dives stay out, and a leftover
/// filter cannot hide any. It is a snapshot, so a dive edited out of the
/// category stays until the diver goes back. The list is pushed over
/// Insights, so its back arrow returns there.
///
/// No ids to show (the dives have since gone, or the load failed) leaves the
/// diver where they are, with a message.
Future<void> openChartDives(
  BuildContext context,
  WidgetRef ref, {
  required String chart,
  required String row,
  required ChartDiveIdsLoader load,
}) async {
  final repository = ref.read(insightsRepositoryProvider);
  final diverId = ref.read(currentDiverIdProvider);
  final scope = ref.read(insightsFilterProvider);

  var ids = const <String>[];
  try {
    ids = await load(repository, diverId, scope);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to load a chart\'s dives',
      error: e,
      stackTrace: stackTrace,
    );
  }
  if (!context.mounted) return;

  final l10n = context.l10n;
  if (ids.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.insights_chart_openDivesFailed)),
    );
    return;
  }
  openDiveList(
    context,
    ref,
    DiveFilterState(
      diveIds: ids,
      diveIdsLabel: l10n.insights_chart_linkLabel(chart, row),
    ),
  );
}

/// [openChartDives] for a chart whose category a filter can state: [narrow]
/// turns the Insights filter into that row's filter.
Future<void> openFilteredChartDives(
  BuildContext context,
  WidgetRef ref, {
  required String chart,
  required String row,
  required DiveFilterState Function(DiveFilterState scope) narrow,
}) => openChartDives(
  context,
  ref,
  chart: chart,
  row: row,
  load: (repository, diverId, scope) =>
      repository.getCountedDiveIds(diverId: diverId, filter: narrow(scope)),
);

/// [openChartDives] for a chart that kept the ids as it counted. Those ids
/// date from the chart's last load, so they are checked against the logbook.
Future<void> openHeldChartDives(
  BuildContext context,
  WidgetRef ref, {
  required String chart,
  required String row,
  required List<String> ids,
}) => openChartDives(
  context,
  ref,
  chart: chart,
  row: row,
  load: (repository, _, _) => repository.getExistingDiveIds(ids),
);
