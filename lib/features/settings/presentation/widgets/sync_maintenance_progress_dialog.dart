import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/services/screen_awake.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One progress reading: [done] of [total] units, under an optional [phase]
/// label. A [total] of 0 means the phase has no countable units and the bar
/// should run indeterminate.
typedef SyncMaintenanceTick = ({int done, int total, String? phase});

/// How a task reports progress to [runWithSyncMaintenanceProgress].
typedef SyncMaintenanceReporter =
    void Function(int done, int total, [String? phase]);

/// Adapts a [SyncMaintenanceReporter] to the plain [SyncCleanupProgress] the
/// cloud cleanup APIs take, tagging every tick with [phase].
SyncCleanupProgress cleanupPhase(
  SyncMaintenanceReporter report,
  String phase,
) =>
    (done, total) => report(done, total, phase);

/// Blocking progress dialog for the long-running Troubleshoot Sync actions.
///
/// Wiping a backend with hundreds of files, or republishing a whole library
/// after one, runs for minutes. Those actions used to `await` in silence behind
/// a live page, so the user saw nothing happening, assumed the app had hung,
/// and killed it -- which interrupted the wipe and left the backend half
/// cleared (issue #1032). This dialog does three things that prevent that:
/// reports real counts, refuses to be dismissed, and says out loud that the app
/// must stay open.
///
/// Modelled on [ImportProgressDialog], which solves the same problem for
/// UDDF/CSV import.
class SyncMaintenanceProgressDialog extends StatelessWidget {
  const SyncMaintenanceProgressDialog({
    super.key,
    required this.title,
    required this.progress,
  });

  final String title;

  /// Null until the first tick -- the listing that fixes the denominator is
  /// itself a network round trip, so the bar starts indeterminate.
  final ValueListenable<SyncMaintenanceTick?> progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // canPop: false blocks the Android back button and any predictive-back
    // gesture for as long as the work runs. It cannot stop a force-quit -- no
    // app can -- so the "keep the app open" line below carries the rest.
    return PopScope(
      canPop: false,
      child: ValueListenableBuilder<SyncMaintenanceTick?>(
        valueListenable: progress,
        builder: (context, value, _) {
          // total == 0 means "working, but with nothing to count" (a phase that
          // is one long operation rather than N files) -> indeterminate bar.
          final fraction = (value == null || value.total == 0)
              ? null
              : value.done / value.total;
          final label = value == null
              ? l10n.settings_import_phase_preparing
              : value.total == 0
              ? (value.phase ?? l10n.settings_syncMaintenance_phase_working)
              : [
                  if (value.phase != null) value.phase!,
                  l10n.settings_syncMaintenance_progress_filesOfTotal(
                    value.done,
                    value.total,
                  ),
                ].join(' - ');
          return Semantics(
            liveRegion: true,
            label: '$title, $label',
            child: AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.settings_syncMaintenance_keepAppOpen,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Runs [task] behind a [SyncMaintenanceProgressDialog], feeding it the task's
/// own progress, and returns the task's result once the dialog has been
/// dismissed.
///
/// The screen is held awake for as long as the dialog is up. The dialog tells
/// the user to keep the app open, and then their phone locked itself and
/// suspended the very work it was asking them not to interrupt (issue #1194).
/// [ScreenAwake.hold] releases the lock however the task ends.
///
/// "Dismissed", precisely: the pop has been issued and the route's future has
/// resolved. That is NOT the same as fully animated out -- a dialog route
/// completes at pop time, not at the end of its exit transition -- so a caller
/// showing a snackbar immediately may briefly overlap the closing dialog. The
/// earlier wording here claimed the stronger guarantee, which was untrue
/// (PR #1033 review); awaiting the route is the strongest ordering this can
/// actually offer without polling the transition.
///
/// The dialog is popped in a `finally`, so a throwing task cannot strand the
/// user behind an undismissable barrier -- the exception then surfaces to the
/// caller, which is what makes honest failure reporting possible.
Future<T> runWithSyncMaintenanceProgress<T>({
  required BuildContext context,
  required String title,
  required Future<T> Function(SyncMaintenanceReporter report) task,
}) => ScreenAwake.hold(
  () => _runWithSyncMaintenanceProgress(
    context: context,
    title: title,
    task: task,
  ),
);

Future<T> _runWithSyncMaintenanceProgress<T>({
  required BuildContext context,
  required String title,
  required Future<T> Function(SyncMaintenanceReporter report) task,
}) async {
  final progress = ValueNotifier<SyncMaintenanceTick?>(null);
  final navigator = Navigator.of(context, rootNavigator: true);
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        SyncMaintenanceProgressDialog(title: title, progress: progress),
  );
  // Dispose only once the route is fully gone. The dialog keeps rebuilding
  // through its exit animation, so disposing right after pop() throws "used
  // after being disposed" -- the same trap _WipeConfirmDialog documents for its
  // text controller.
  unawaited(dialog.whenComplete(progress.dispose));
  try {
    return await task(
      (done, total, [phase]) =>
          progress.value = (done: done, total: total, phase: phase),
    );
  } finally {
    if (navigator.canPop()) navigator.pop();
    // Await the ROUTE, not just the pop. Returning the moment the task
    // finished let callers show their result snackbar while the dialog was
    // still animating out, and made the "returns once the dialog has closed"
    // contract above untrue (PR #1033 review).
    await dialog;
  }
}
