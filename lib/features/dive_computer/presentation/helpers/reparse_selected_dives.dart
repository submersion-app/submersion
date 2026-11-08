import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/reparse_batch_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

const _log = LoggerService('reparseSelectedDives');

/// The dive list's "Re-parse" bulk action (issue #224): confirms, then
/// re-parses the [selectedIds] that have stored raw data and leaves the rest
/// alone. Returns [BulkActionOutcome.cancelled], keeping the selection, when
/// nothing ran.
Future<BulkActionOutcome> reparseSelectedDives(
  BuildContext context,
  WidgetRef ref,
  List<String> selectedIds,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final List<String> diveIds;
  try {
    diveIds = await ref
        .read(reparseBatchServiceProvider)
        .withRawData(selectedIds);
  } catch (e, stackTrace) {
    _log.error(
      'Could not check the selected dives for raw data',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    return BulkActionOutcome.failed;
  }
  if (!context.mounted) return BulkActionOutcome.cancelled;
  if (diveIds.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.reparseBatch_noneWithRawData)),
    );
    return BulkActionOutcome.cancelled;
  }

  final confirmed = await confirmBatchReparse(
    context,
    count: diveIds.length,
    skipped: selectedIds.length - diveIds.length,
  );
  if (!confirmed || !context.mounted) return BulkActionOutcome.cancelled;

  await runReparseBatch(context, ref, diveIds);
  return BulkActionOutcome.completed;
}
