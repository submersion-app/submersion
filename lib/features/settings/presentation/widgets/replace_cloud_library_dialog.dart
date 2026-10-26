import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/typed_word_confirm_dialog.dart';

/// Confirmation for making this device's library authoritative everywhere.
///
/// Provider-free and self-contained so the type-to-confirm gate can be widget
/// tested directly; [showReplaceCloudLibraryDialog] supplies the surrounding
/// backup and sync calls. Pops true when the user confirms.
class ReplaceCloudLibraryDialog extends StatelessWidget {
  const ReplaceCloudLibraryDialog({
    super.key,
    required this.localDiveCount,
    required this.peerFileCount,
  });

  final int localDiveCount;

  /// Null only when the peer listing failed; zero is a real answer.
  final int? peerFileCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final peers = peerFileCount;
    return TypedWordConfirmDialog(
      warning: true,
      title: l10n.settings_cloudSync_replaceLibrary_dialogTitle,
      paragraphs: [
        l10n.settings_cloudSync_replaceLibrary_dialogIntro,
        l10n.settings_cloudSync_replaceLibrary_dialogBody(localDiveCount),
        peers == null
            ? l10n.settings_cloudSync_replaceLibrary_peersUnknown
            : l10n.settings_cloudSync_replaceLibrary_peers(peers),
        l10n.settings_cloudSync_replaceLibrary_backupNote,
      ],
      word: l10n.settings_cloudSync_replaceLibrary_confirmWord,
      hint: l10n.settings_cloudSync_replaceLibrary_confirmHint,
      confirmLabel: l10n.settings_cloudSync_replaceLibrary_confirm,
    );
  }
}

/// Confirm and run a library replacement from this device.
///
/// The safety backup runs here rather than in SyncNotifier because backup
/// providers import sync providers; this widget layer may import both. Mirrors
/// showAdoptReplacedLibraryDialog.
Future<void> showReplaceCloudLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  ReplacePreflight preflight,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ReplaceCloudLibraryDialog(
      localDiveCount: preflight.localDiveCount,
      peerFileCount: preflight.peerFileCount,
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // A safety backup followed by a whole-library republish runs for minutes on
  // a large library. Both used to happen behind a live page, so the user saw
  // nothing and their phone was free to lock mid-replace (issue #1194).
  await runWithSyncMaintenanceProgress<void>(
    context: context,
    title: l10n.settings_cloudSync_replaceLibrary_progressTitle,
    task: (report) async {
      // Safety backup of this device BEFORE the cloud library is overwritten.
      report(0, 0, l10n.settings_syncMaintenance_phase_backingUp);
      await ref.read(backupServiceProvider).performBackup(isAutomatic: true);
      report(0, 0, l10n.settings_syncMaintenance_phase_publishingLibrary);
      await ref
          .read(syncStateProvider.notifier)
          .replaceCloudLibraryFromThisDevice();
    },
  );
}
