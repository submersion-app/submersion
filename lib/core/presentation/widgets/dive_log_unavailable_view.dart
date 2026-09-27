import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_restore_status.dart';
import 'package:submersion/core/presentation/widgets/startup_recovery_route.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/dive_log_availability.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Startup screen shown when the dive log a custom folder points at is not on
/// this device (issue #2177).
///
/// Shown BEFORE anything is opened. Opening would create a new, empty dive
/// log in its place, which is what used to happen: the diver landed in a
/// working app with no dives and no warning, and a later backup or sync could
/// spread the empty state.
///
/// For a dive log still in iCloud only the routes that leave the folder alone
/// are offered. A new or restored file written beside an iCloud placeholder
/// leaves iCloud two dive logs to reconcile, and the empty one can win.
class DiveLogUnavailableView extends StatelessWidget {
  const DiveLogUnavailableView({
    super.key,
    required this.availability,
    required this.folderPath,
    required this.textColor,
    required this.subtitleColor,
    required this.onTryAgain,
    required this.onUseAnotherFolder,
    required this.onRestoreFromFile,
    required this.onStartNew,
    required this.onClose,
    this.busy = false,
    this.restoreStatus = StartupRestoreStatus.idle,
    this.restoreError,
  }) : assert(availability != DiveLogAvailability.ready);

  final DiveLogAvailability availability;

  /// The configured dive log folder, named so the diver can check it by hand.
  final String folderPath;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTryAgain;
  final VoidCallback onUseAnotherFolder;

  /// Offered only for a missing dive log; see the class comment.
  final VoidCallback onRestoreFromFile;

  /// Offered only for a missing dive log; see the class comment.
  final VoidCallback onStartNew;
  final VoidCallback onClose;

  /// True while one of the routes is running. Every route acts on the same
  /// folder, so none may start while another is still going.
  final bool busy;
  final StartupRestoreStatus restoreStatus;
  final String? restoreError;

  bool get _inICloud => availability == DiveLogAvailability.inICloudOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final restoring = restoreStatus == StartupRestoreStatus.running;
    final locked = busy || restoring;
    final bodyStyle = TextStyle(fontSize: 14, color: subtitleColor);

    // Scrolls itself, exactly as InterruptedRestoreView does: StartupWrapper
    // hosts terminal screens in a bare SafeArea > Center.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _inICloud ? Icons.cloud_download_outlined : Icons.folder_off,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _inICloud
                  ? l10n.startup_diveLogUnavailable_iCloud_title
                  : l10n.startup_diveLogUnavailable_missing_title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              // Selectable so the folder can be pasted into a file manager or
              // a support message.
              child: SelectableText(
                _inICloud
                    ? l10n.startup_diveLogUnavailable_iCloud_body(folderPath)
                    : l10n.startup_diveLogUnavailable_missing_body(
                        folderPath,
                        DatabaseLocationService.databaseFilename,
                      ),
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('diveLogUnavailable_tryAgain'),
              onPressed: locked ? null : onTryAgain,
              child: Text(l10n.common_action_tryAgain),
            ),
            if (restoring) ...[
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (restoreStatus == StartupRestoreStatus.failed) ...[
              const SizedBox(height: 16),
              Text(
                l10n.startup_failure_restoreFailed,
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
              if (restoreError != null && restoreError!.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  restoreError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              l10n.startup_failure_moreWays_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            // Ordered by how much of the diver's data each one keeps, the
            // empty dive log last, as on the startup failure screen.
            StartupRecoveryRoute(
              icon: Icons.folder_special_outlined,
              label: l10n.startup_failure_useAnotherFolder,
              description: l10n.startup_failure_useAnotherFolder_subtitle,
              onPressed: locked ? null : onUseAnotherFolder,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            if (!_inICloud) ...[
              StartupRecoveryRoute(
                icon: Icons.restore_page_outlined,
                label: l10n.startup_failure_restoreFromFile,
                description: l10n.startup_failure_restoreFromFile_subtitle,
                onPressed: locked ? null : onRestoreFromFile,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              StartupRecoveryRoute(
                icon: Icons.note_add_outlined,
                label: l10n.startup_diveLogUnavailable_startNew,
                description: l10n.startup_diveLogUnavailable_startNew_subtitle,
                onPressed: locked ? null : onStartNew,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: onClose,
              child: Text(l10n.common_action_close),
            ),
          ],
        ),
      ),
    );
  }
}
