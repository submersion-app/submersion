import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation for making this device's library authoritative everywhere.
///
/// Provider-free and self-contained so the type-to-confirm gate can be widget
/// tested directly; [showReplaceCloudLibraryDialog] supplies the surrounding
/// backup and sync calls. Pops true when the user confirms.
class ReplaceCloudLibraryDialog extends StatefulWidget {
  const ReplaceCloudLibraryDialog({
    super.key,
    required this.localDiveCount,
    required this.peerFileCount,
  });

  final int localDiveCount;

  /// Null only when the peer listing failed; zero is a real answer.
  final int? peerFileCount;

  @override
  State<ReplaceCloudLibraryDialog> createState() =>
      _ReplaceCloudLibraryDialogState();
}

class _ReplaceCloudLibraryDialogState extends State<ReplaceCloudLibraryDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // The expected word is localized: comparing against a hardcoded English
    // one made the reset dialog impossible to confirm in seven locales.
    final expected = context.l10n.settings_cloudSync_replaceLibrary_confirmWord;
    final confirmed = _controller.text.trim() == expected;
    if (confirmed != _isConfirmed) {
      setState(() => _isConfirmed = confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final peers = widget.peerFileCount;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.settings_cloudSync_replaceLibrary_dialogTitle),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_cloudSync_replaceLibrary_dialogIntro,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settings_cloudSync_replaceLibrary_dialogBody(
                widget.localDiveCount,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              peers == null
                  ? l10n.settings_cloudSync_replaceLibrary_peersUnknown
                  : l10n.settings_cloudSync_replaceLibrary_peers(peers),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settings_cloudSync_replaceLibrary_backupNote,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.settings_cloudSync_replaceLibrary_confirmHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.settings_cloudSync_replaceLibrary_confirm),
        ),
      ],
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
