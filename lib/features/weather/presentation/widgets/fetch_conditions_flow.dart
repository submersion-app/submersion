import 'package:flutter/material.dart';

import 'package:submersion/features/weather/data/services/bulk_conditions_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Runs a conditions fetch: count, confirm, progress, summary.
///
/// Covers the whole logbook (for [diverId] when given), or only the dives in
/// [diveIds] when the selection bar starts it (#4329). A selection is worded
/// as such: "2 of 3 selected dives are missing conditions", plus a line for
/// checked dives that have nowhere to fetch for.
///
/// Reports a [BulkActionOutcome] so the selection bar knows whether to leave
/// selection mode: [BulkActionOutcome.completed] once a run happened, even a
/// cancelled one (it may have written), [BulkActionOutcome.cancelled] when
/// nothing was attempted, [BulkActionOutcome.failed] on an error.
///
/// Kept out of the dive list so the list keeps its own size and the flow can
/// be widget-tested against a [BulkConditionsService] built over a test
/// database, with no navigation or provider scaffolding.
Future<BulkActionOutcome> showFetchConditionsFlow({
  required BuildContext context,
  required BulkConditionsService service,
  String? diverId,
  Set<String>? diveIds,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  final int candidates;
  final int unlocated;
  final int? selected;
  try {
    // Independent reads, so they run together. Future.wait rather than a
    // record's `.wait`: it rethrows the original error, which the snackbar
    // shows, instead of wrapping it in a ParallelWaitError.
    final counts = await Future.wait<int>([
      service.countCandidates(diverId: diverId, diveIds: diveIds),
      // Only a selection says what it will skip: across the whole logbook
      // the menu entry has always meant "whatever can be filled".
      if (diveIds != null) ...[
        service.countWithoutLocation(diverId: diverId, diveIds: diveIds),
        // Planned dives are never fetched for, so "3 of 5 selected" would
        // leave two checked dives unexplained. The share is of logged dives.
        service.countLogged(diveIds),
      ],
    ]);
    candidates = counts.first;
    unlocated = diveIds == null ? 0 : counts[1];
    selected = diveIds == null ? null : counts[2];
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    return BulkActionOutcome.failed;
  }

  if (!context.mounted) return BulkActionOutcome.cancelled;
  if (candidates == 0) {
    final String message;
    if (diveIds == null) {
      message = l10n.diveLog_fetchConditions_noneNeeded;
    } else if (unlocated > 0) {
      message = l10n.diveLog_fetchConditions_noneLocatedSelected;
    } else {
      message = l10n.diveLog_fetchConditions_noneNeededSelected;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return BulkActionOutcome.cancelled;
  }

  final body = selected != null && candidates < selected
      ? l10n.diveLog_fetchConditions_confirmBodySelected(candidates, selected)
      : l10n.diveLog_fetchConditions_confirmBody(candidates);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.diveLog_fetchConditions_confirmTitle),
      content: Text(
        unlocated > 0
            ? '$body\n\n'
                  '${l10n.diveLog_fetchConditions_skippedNoLocation(unlocated)}'
            : body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.diveLog_fetchConditions_confirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return BulkActionOutcome.cancelled;

  final controller = FetchConditionsProgressController(total: candidates);
  final progressDialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ProgressDialog(controller: controller),
  );

  BulkConditionsResult? result;
  Object? failure;
  try {
    result = await service.run(
      diverId: diverId,
      diveIds: diveIds,
      onProgress: controller.report,
      isCancelled: () => controller.cancelled,
    );
  } catch (e) {
    failure = e;
  }

  // Close the progress dialog before anything else can be shown over it, and
  // only retire the controller once nothing is listening to it any more.
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    await progressDialog;
  }
  controller.dispose();

  if (failure != null) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('$failure')));
    }
    return BulkActionOutcome.failed;
  }
  if (!context.mounted) return BulkActionOutcome.completed;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _SummaryDialog(result: result!),
  );
  return BulkActionOutcome.completed;
}

/// Shared state between the run and its progress dialog: the dialog listens
/// for counts, the run polls [cancelled].
class FetchConditionsProgressController extends ChangeNotifier {
  FetchConditionsProgressController({required this.total});

  /// Seeded from the count shown in the confirm dialog, then replaced by the
  /// total the run itself reports. The two are separate reads of the candidate
  /// set, so anything that changed in between would otherwise leave the bar
  /// short of, or past, the end.
  int total;
  int completed = 0;
  bool cancelled = false;
  bool _disposed = false;

  void report(BulkConditionsProgress progress) {
    if (_disposed) return;
    completed = progress.completed;
    total = progress.total;
    notifyListeners();
  }

  void cancel() {
    if (_disposed) return;
    cancelled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.controller});

  final FetchConditionsProgressController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.diveLog_fetchConditions_progressTitle),
      content: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Determinate on purpose: an indeterminate indicator animates
            // forever, which never lets a widget test settle.
            LinearProgressIndicator(
              value: controller.total == 0
                  ? 0
                  : controller.completed / controller.total,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diveLog_fetchConditions_progressCount(
                controller.completed,
                controller.total,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: controller.cancel,
          child: Text(l10n.common_action_cancel),
        ),
      ],
    );
  }
}

class _SummaryDialog extends StatelessWidget {
  const _SummaryDialog({required this.result});

  final BulkConditionsResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = <String>[
      if (result.filled > 0)
        l10n.diveLog_fetchConditions_summaryFilled(result.filled),
      if (result.unavailable > 0)
        l10n.diveLog_fetchConditions_summaryUnavailable(result.unavailable),
      if (result.unchanged > 0)
        l10n.diveLog_fetchConditions_summaryUnchanged(result.unchanged),
      if (result.cancelled)
        l10n.diveLog_fetchConditions_summaryCancelled(result.processed),
    ];

    return AlertDialog(
      title: Text(l10n.diveLog_fetchConditions_summaryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) Text(line)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_ok),
        ),
      ],
    );
  }
}
