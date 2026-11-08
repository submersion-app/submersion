import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/reparse_batch_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(ReparseDivesPage);

/// What the whole-log re-parse would cover for the active diver.
class ReparseDivesOverview {
  const ReparseDivesOverview({
    required this.total,
    required this.byComputer,
    required this.withoutRawData,
  });

  /// Dives with raw data. A dive with two computers' data counts once here
  /// and once under each computer.
  final int total;
  final List<ComputerRawDataCount> byComputer;
  final int withoutRawData;
}

/// Refreshed whenever a data source or dive row changes, so a download, a
/// discard, a new manual dive or a synced change does not leave a stale
/// count behind.
final reparseDivesOverviewProvider = FutureProvider<ReparseDivesOverview>((
  ref,
) async {
  final batch = ref.watch(reparseBatchServiceProvider);
  final db = ref.watch(reparseServiceProvider).db;
  ref.invalidateSelfWhen(
    db.tableUpdates(
      TableUpdateQuery.onAllTables([db.diveDataSources, db.dives]),
    ),
  );
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final (ids, byComputer, withoutRawData) = await (
    batch.diveIdsWithRawData(diverId: diverId),
    batch.rawDataCountsByComputer(diverId: diverId),
    batch.diveCountWithoutRawData(diverId: diverId),
  ).wait;
  return ReparseDivesOverview(
    total: ids.length,
    byComputer: byComputer,
    withoutRawData: withoutRawData,
  );
});

/// Settings > Data > Data tools > Re-parse dives (issue #224): re-runs the
/// dive parser on every dive of the active diver that has stored raw data.
class ReparseDivesPage extends ConsumerWidget {
  const ReparseDivesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(reparseDivesOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_reparseDives_title)),
      body: overview.when(
        data: (o) => _Overview(overview: o),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stackTrace) {
          _log.error(
            'Could not count the dives to re-parse',
            error: e,
            stackTrace: stackTrace,
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.common_error_tryAgain),
            ),
          );
        },
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.overview});

  final ReparseDivesOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final empty = overview.total == 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.settings_reparseDives_intro,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.settings_reparseDives_withRawData(overview.total),
          style: theme.textTheme.titleMedium,
        ),
        if (overview.byComputer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.settings_reparseDives_byComputer,
            style: theme.textTheme.labelLarge,
          ),
          for (final computer in overview.byComputer)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.watch_outlined),
              title: Text(
                computer.computerName.isEmpty
                    ? l10n.settings_reparseDives_unknownComputer
                    : computer.computerName,
              ),
              trailing: Text('${computer.dives}'),
            ),
        ],
        if (overview.withoutRawData > 0) ...[
          const SizedBox(height: 8),
          Text(
            l10n.settings_reparseDives_withoutRawData(overview.withoutRawData),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        if (empty) ...[
          Text(l10n.settings_reparseDives_none),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: empty ? null : () => _reparseAll(context, ref),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.settings_reparseDives_button),
          ),
        ),
      ],
    );
  }

  Future<void> _reparseAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmBatchReparse(context, count: overview.total);
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    final List<String> diveIds;
    try {
      // Listed again now, not taken from the overview, so a dive downloaded
      // while the confirmation was open is included.
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      diveIds = await ref
          .read(reparseBatchServiceProvider)
          .diveIdsWithRawData(diverId: diverId);
    } catch (e, stackTrace) {
      _log.error(
        'Could not list the dives to re-parse',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (diveIds.isEmpty || !context.mounted) return;
    await runReparseBatch(context, ref, diveIds);
  }
}
