import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver chose when leaving the wizard while an import runs.
enum LeaveRunningImportChoice { stay, cancelImport, continueInBackground }

/// [GoRoute.onExit] for an import wizard: leaving while its import runs asks
/// first. An import that can go on without the wizard may continue in the
/// background or be cancelled; any other is cancelled by leaving, so the
/// diver may only cancel it or stay. Staying, or dismissing the dialog,
/// keeps the diver on the wizard.
///
/// Only the wizard that started the import asks: a job that already runs on
/// alone belongs to no wizard on screen ([ImportJobState.isAttached]).
Future<bool> confirmLeaveRunningImport(
  BuildContext context,
  GoRouterState state,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final job = container.read(importJobProvider);
  if (!job.isRunning || !job.isAttached || job.isCancellationRequested) {
    return true;
  }
  final choice = await showDialog<LeaveRunningImportChoice>(
    context: context,
    builder: (_) => LeaveRunningImportDialog(
      canContinueInBackground: job.continuesWithoutWizard,
    ),
  );
  switch (choice) {
    case LeaveRunningImportChoice.continueInBackground:
      return true;
    case LeaveRunningImportChoice.cancelImport:
      container.read(importJobProvider.notifier).cancel();
      return true;
    case LeaveRunningImportChoice.stay:
    case null:
      return false;
  }
}

class LeaveRunningImportDialog extends StatelessWidget {
  const LeaveRunningImportDialog({
    super.key,
    required this.canContinueInBackground,
  });

  final bool canContinueInBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void choose(LeaveRunningImportChoice choice) =>
        Navigator.of(context).pop(choice);
    return AlertDialog(
      title: Text(l10n.universalImport_leave_title),
      content: Text(
        canContinueInBackground
            ? l10n.universalImport_leave_body
            : l10n.universalImport_leave_bodyStops,
      ),
      actions: [
        TextButton(
          onPressed: () => choose(LeaveRunningImportChoice.stay),
          child: Text(l10n.universalImport_leave_stay),
        ),
        if (canContinueInBackground) ...[
          TextButton(
            onPressed: () => choose(LeaveRunningImportChoice.cancelImport),
            child: Text(l10n.universalImport_cancel_confirmAction),
          ),
          FilledButton(
            onPressed: () =>
                choose(LeaveRunningImportChoice.continueInBackground),
            child: Text(l10n.universalImport_leave_continueInBackground),
          ),
        ] else
          FilledButton(
            onPressed: () => choose(LeaveRunningImportChoice.cancelImport),
            child: Text(l10n.universalImport_cancel_confirmAction),
          ),
      ],
    );
  }
}
