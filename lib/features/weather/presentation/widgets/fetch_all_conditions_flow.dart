import 'package:flutter/material.dart';

import 'package:submersion/features/weather/data/services/bulk_conditions_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Runs a "fetch conditions for all dives" pass: count, confirm, progress,
/// summary.
///
/// Kept out of the dive list page so the page keeps its own size and the flow
/// can be widget-tested against a [BulkConditionsService] built over a test
/// database, with no navigation or provider scaffolding.
Future<void> showFetchAllConditionsFlow({
  required BuildContext context,
  required BulkConditionsService service,
  String? diverId,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  final int candidates;
  try {
    candidates = await service.countCandidates(diverId: diverId);
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return;
  }

  if (!context.mounted) return;
  if (candidates == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_fetchConditions_noneNeeded)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.diveLog_fetchConditions_confirmTitle),
      content: Text(l10n.diveLog_fetchConditions_confirmBody(candidates)),
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
  if (confirmed != true || !context.mounted) return;

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

  if (!context.mounted) return;
  if (failure != null) {
    messenger.showSnackBar(SnackBar(content: Text('$failure')));
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => _SummaryDialog(result: result!),
  );
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
