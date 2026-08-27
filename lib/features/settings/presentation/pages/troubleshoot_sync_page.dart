import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/features/settings/presentation/pages/sync_devices_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Recovery actions for a wedged Cloud Sync state (issue #509). Reached from
/// the Cloud Sync page's Advanced section and by tapping the sync-error banner.
/// Actions escalate in severity; each explains itself in plain language.
class TroubleshootSyncPage extends ConsumerWidget {
  const TroubleshootSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_troubleshootSync_appBar_title)),
      body: ListView(
        children: [
          _buildEncryptionStatusRow(context, ref),
          ListTile(
            leading: const Icon(Icons.healing),
            title: Text(l10n.settings_troubleshootSync_repair_title),
            subtitle: Text(l10n.settings_troubleshootSync_repair_subtitle),
            onTap: () => _confirmRepair(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(l10n.settings_troubleshootSync_rebuild_title),
            subtitle: Text(l10n.settings_troubleshootSync_rebuild_subtitle),
            onTap: () => _confirmRebuild(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: Text(l10n.settings_syncDevices_appBar_title),
            subtitle: Text(l10n.settings_troubleshootSync_devices_subtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const SyncDevicesPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.settings_troubleshootSync_removeThisDevice_title),
            subtitle: Text(
              l10n.settings_troubleshootSync_removeThisDevice_subtitle,
            ),
            onTap: () => _confirmRemoveThisDevice(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.settings_troubleshootSync_wipeAll_title),
            subtitle: Text(l10n.settings_troubleshootSync_wipeAll_subtitle),
            onTap: () => _confirmWipeAll(context, ref),
          ),
        ],
      ),
    );
  }

  /// Encryption status: Off / On / Locked. Locked (flag on, no unlocked
  /// session) is tappable and runs the shared unlock flow -- the most
  /// common "sync stopped working" cause on a freshly restored device.
  /// Uses the same localized strings as the Cloud Sync page.
  Widget _buildEncryptionStatusRow(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(syncPreferencesProvider).syncEncryptionEnabled;
    final session = ref.watch(encryptionKeyNotifierProvider);
    final locked = enabled && session == null;
    final String subtitle;
    if (!enabled) {
      subtitle = l10n.settings_cloudSync_encryption_statusOff;
    } else if (locked) {
      subtitle = l10n.settings_cloudSync_encryption_statusLockedSubtitle;
    } else {
      subtitle = l10n.settings_cloudSync_encryption_statusOn;
    }
    return ListTile(
      leading: Icon(
        locked ? Icons.lock_clock : Icons.lock_outline,
        color: locked ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(l10n.settings_cloudSync_encryption_title),
      subtitle: Text(subtitle),
      onTap: locked ? () => runEncryptionUnlockFlow(context, ref) : null,
    );
  }

  Future<void> _confirmRepair(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_troubleshootSync_repair_confirmTitle),
        content: Text(l10n.settings_troubleshootSync_repair_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_troubleshootSync_repair_confirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Clearing local sync state and re-reading the backend is quick on a small
    // library and minutes-long on a large one. Behind a live page it looked
    // like nothing happened at all (issue #1194), so it gets the same blocking
    // dialog -- and the same wakelock -- as the other maintenance actions.
    await runWithSyncMaintenanceProgress<void>(
      context: context,
      title: l10n.settings_troubleshootSync_repair_progressTitle,
      task: (report) async {
        report(0, 0, l10n.settings_syncMaintenance_phase_repairing);
        await ref.read(syncStateProvider.notifier).repairSync();
      },
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settings_troubleshootSync_repair_doneSnack),
        ),
      );
    }
  }

  Future<void> _confirmRebuild(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_troubleshootSync_rebuild_confirmTitle),
        content: Text(l10n.settings_troubleshootSync_rebuild_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_troubleshootSync_rebuild_confirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runWithSyncMaintenanceProgress(
      context: context,
      title: l10n.settings_troubleshootSync_rebuild_progressTitle,
      task: (report) => ref
          .read(syncStateProvider.notifier)
          .rebuildBackendFromThisDevice(
            onProgress: cleanupPhase(
              report,
              l10n.settings_syncMaintenance_phase_clearingOldFiles,
            ),
            // The republish that follows the clear-out uploads the whole
            // library. It has no file count of its own here, so flip the bar
            // to indeterminate rather than leave it parked at 100% looking
            // finished while minutes of upload remain (issue #1032).
            onPublishStarted: () => report(
              0,
              0,
              l10n.settings_syncMaintenance_phase_publishingLibrary,
            ),
          ),
    );
    if (!context.mounted) return;
    // The rebuild can fail (e.g. no epoch marker to rebuild from), in which case
    // the notifier surfaces SyncStatus.error -- reflect that instead of always
    // claiming success.
    final state = ref.read(syncStateProvider);
    final failed = state.status == SyncStatus.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed
              ? (state.message ??
                    l10n.settings_troubleshootSync_rebuild_failedSnack)
              : l10n.settings_troubleshootSync_rebuild_doneSnack,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveThisDevice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.settings_troubleshootSync_removeThisDevice_confirmTitle,
        ),
        content: Text(
          l10n.settings_troubleshootSync_removeThisDevice_confirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.common_action_remove),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final outcome = await runWithSyncMaintenanceProgress(
      context: context,
      title: l10n.settings_troubleshootSync_removeThisDevice_progressTitle,
      task: (report) => ref
          .read(syncStateProvider.notifier)
          .removeThisDeviceCloudFiles(
            onProgress: cleanupPhase(
              report,
              l10n.settings_syncMaintenance_phase_deleting,
            ),
          ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanupMessage(l10n, outcome, wiped: false))),
      );
    }
  }

  /// Report what the cleanup actually achieved.
  ///
  /// These operations are best-effort: an offline provider or a timed-out
  /// listing leaves files behind. Claiming success regardless is what sent the
  /// reporter of issue #1032 away believing a wipe had completed when it had
  /// not, leaving the backend in a state no later sync could explain.
  /// [wiped] selects between two fully-formed localized sentences rather than
  /// interpolating an English verb. A verb glued into a sentence cannot be
  /// translated: other languages inflect and reorder around it.
  static String _cleanupMessage(
    AppLocalizations l10n,
    SyncCleanupOutcome outcome, {
    required bool wiped,
  }) {
    if (outcome.isComplete) {
      return wiped
          ? l10n.settings_syncMaintenance_wipedFiles(outcome.deleted)
          : l10n.settings_syncMaintenance_removedFiles(outcome.deleted);
    }
    final trouble = <String>[
      if (outcome.failed > 0)
        l10n.settings_syncMaintenance_trouble_failed(outcome.failed),
      if (outcome.listIncomplete)
        l10n.settings_syncMaintenance_trouble_listIncomplete,
    ].join('; ');
    return wiped
        ? l10n.settings_syncMaintenance_wipedFilesPartial(
            outcome.deleted,
            trouble,
          )
        : l10n.settings_syncMaintenance_removedFilesPartial(
            outcome.deleted,
            trouble,
          );
  }

  /// Destructive full-backend wipe: guarded by typing the word WIPE so it
  /// cannot be triggered by a single mis-tap. The confirmation controller is
  /// owned by [_WipeConfirmDialog]'s State (never disposed inline after
  /// showDialog, which would be used again during the dialog's exit animation).
  Future<void> _confirmWipeAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => const _WipeConfirmDialog(),
    );
    if (ok != true || !context.mounted) return;
    final outcome = await runWithSyncMaintenanceProgress(
      context: context,
      title: l10n.settings_troubleshootSync_wipeAll_progressTitle,
      task: (report) => ref
          .read(syncStateProvider.notifier)
          .wipeAllCloudSyncData(
            onProgress: cleanupPhase(
              report,
              l10n.settings_syncMaintenance_phase_deleting,
            ),
          ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanupMessage(l10n, outcome, wiped: true))),
      );
    }
  }
}

/// Typed-confirmation dialog for the destructive full-backend wipe. Owns its
/// [TextEditingController] so it is disposed with the widget, not inline after
/// showDialog (which the dialog's exit animation would then rebuild against).
/// The word the user must type to arm the wipe. Deliberately NOT localized:
/// the dialog body, the field hint and the comparison in [build] all render
/// this one constant, so the confirm button stays satisfiable in every locale.
/// Translating the hint while leaving the comparison in English would make the
/// button unreachable outside English.
const String _wipeSentinel = 'WIPE';

class _WipeConfirmDialog extends StatefulWidget {
  const _WipeConfirmDialog();

  @override
  State<_WipeConfirmDialog> createState() => _WipeConfirmDialogState();
}

class _WipeConfirmDialogState extends State<_WipeConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final armed = _controller.text.trim() == _wipeSentinel;
    return AlertDialog(
      title: Text(l10n.settings_troubleshootSync_wipeAll_confirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_troubleshootSync_wipeAll_confirmBody(_wipeSentinel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: _wipeSentinel,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: armed ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.settings_troubleshootSync_wipeAll_confirm),
        ),
      ],
    );
  }
}
