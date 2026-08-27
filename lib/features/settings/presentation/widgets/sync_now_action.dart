import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Run a sync, first handling the two gated cases: a replaced cloud library
/// awaiting adoption, and the device's first library-combining contact with
/// existing cloud data.
///
/// Shared rather than private to the Cloud Sync page because the Home sync
/// chip triggers a sync too. Calling `performSync()` directly from a second
/// entry point would skip these gates -- and the first-contact gate guards an
/// irreversible merge of two libraries, so it must not be bypassable by
/// whichever surface the user happened to tap.
Future<void> runSyncNow(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(syncStateProvider.notifier);
  final replaceInfo = await notifier.libraryReplaceInfo();
  if (replaceInfo != null) {
    if (!context.mounted) return;
    await showAdoptReplacedLibraryDialog(context, ref, replaceInfo);
    return;
  }
  final info = await notifier.firstSyncMergeInfo();
  if (info == null) {
    await notifier.performSync();
    return;
  }
  if (!context.mounted) return;
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settings_cloudSync_firstSync_dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_cloudSync_firstSync_dialogContent(
                info.peerFileCount,
                info.localDiveCount,
              ),
            ),
            const SizedBox(height: 12),
            // Merge is the only action here on purpose; the alternative is
            // a fleet-wide wipe and does not belong one tap away in a
            // dialog that appears routinely. Name where it lives instead.
            Text(l10n.settings_cloudSync_firstSync_replaceHint),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settings_cloudSync_firstSync_dialogConfirm),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await notifier.performSync();
  }
}
