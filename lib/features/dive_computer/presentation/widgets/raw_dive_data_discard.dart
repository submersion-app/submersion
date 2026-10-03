import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/dive_computer/data/services/raw_dive_data_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

final _log = LoggerService.forClass(RawDiveDataTile);

/// Asks before discarding raw dive computer data, then discards it and
/// reports the outcome (issue #1376). [computerId] null discards every
/// computer's. [message] names what is about to go, since the dialog is the
/// last point at which the diver can keep the ability to re-parse.
Future<void> confirmAndDiscardRawDiveData(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  String? computerId,
}) async {
  final l10n = context.l10n;
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.diveComputer_rawData_discardTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.diveComputer_rawData_discardAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(rawDiveDataServiceProvider);
  String outcome;
  try {
    final cleared = await service.discard(computerId: computerId);
    outcome = l10n.diveComputer_rawData_discarded(cleared);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to discard raw dive data',
      error: e,
      stackTrace: stackTrace,
    );
    outcome = l10n.diveComputer_rawData_discardFailed;
  }
  // No invalidation needed: the counts, the usage tile and the dive page's
  // re-parse entry all refresh themselves when a data source row changes.
  messenger.showSnackBar(SnackBar(content: Text(outcome)));
}

/// [confirmAndDiscardRawDiveData] for one [computer]. The dialog counts dives
/// rather than the counter's source rows, matching what the discard reports.
Future<void> confirmAndDiscardComputerRawDiveData(
  BuildContext context,
  WidgetRef ref,
  DiveComputer computer,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.diveComputer_rawData_discardFailed;
  final RawDiveDataUsage usage;
  try {
    usage = await ref
        .read(rawDiveDataServiceProvider)
        .getUsage(computerId: computer.id);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to count raw dive data for ${computer.id}',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  if (usage.diveCount == 0 || !context.mounted) return;
  await confirmAndDiscardRawDiveData(
    context,
    ref,
    computerId: computer.id,
    message: context.l10n.diveComputer_rawData_discardComputerMessage(
      computer.displayName,
      usage.diveCount,
    ),
  );
}

/// How much raw dive computer data the library keeps across every computer,
/// with the action to discard it all. Hidden while there is none.
class RawDiveDataTile extends ConsumerWidget {
  const RawDiveDataTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(rawDiveDataUsageProvider).value;
    if (usage == null || usage.diveCount == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final size = formatBytes(usage.storedBytes);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const ValueKey('raw_dive_data_tile'),
          leading: const Icon(Icons.memory),
          title: Text(l10n.diveComputer_rawData_tileTitle),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.diveComputer_rawData_tileSubtitle(usage.diveCount, size),
              ),
              TileSubtitleAction(
                actionKey: const ValueKey('raw_dive_data_discard_all'),
                onPressed: () => confirmAndDiscardRawDiveData(
                  context,
                  ref,
                  message: l10n.diveComputer_rawData_discardAllMessage(
                    usage.diveCount,
                    size,
                  ),
                ),
                label: l10n.diveComputer_rawData_discardButton,
              ),
            ],
          ),
          isThreeLine: true,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
