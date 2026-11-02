import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/features/settings/presentation/providers/web_forget_device_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The rows a browser adds to the Sync page (issue #4121): which storage
/// the database landed in, the remember switch, and Forget this device.
class WebSyncRows extends ConsumerWidget {
  const WebSyncRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(webDatabaseStatusProvider);
    final persists = status?.persists ?? true;
    return Column(
      children: [
        ListTile(
          leading: Icon(
            persists ? Icons.storage : Icons.warning_amber,
            color: persists ? null : Theme.of(context).colorScheme.error,
          ),
          title: Text(l10n.web_storage_title),
          subtitle: status == null ? null : Text(_describe(l10n, status)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.key),
          title: Text(l10n.web_rememberOnThisDevice_title),
          subtitle: Text(l10n.web_rememberOnThisDevice_subtitle),
          value: ref.watch(rememberCredentialsProvider),
          onChanged: (value) =>
              ref.read(rememberCredentialsProvider.notifier).set(value),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(l10n.web_forgetDevice_title),
          subtitle: Text(l10n.web_forgetDevice_subtitle),
          onTap: () => _confirmForget(context, ref),
        ),
      ],
    );
  }

  static String _describe(AppLocalizations l10n, WebDatabaseStatus status) =>
      switch (status.storage) {
        WebDatabaseStorage.opfsShared ||
        WebDatabaseStorage.opfsLocks => l10n.web_storage_opfs,
        WebDatabaseStorage.sharedIndexedDb ||
        WebDatabaseStorage.unsafeIndexedDb ||
        WebDatabaseStorage.unknown => l10n.web_storage_indexedDb,
        WebDatabaseStorage.inMemory => l10n.web_storage_memoryWarning,
      };

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.web_forgetDevice_title),
        content: Text(l10n.web_forgetDevice_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.web_forgetDevice_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(webForgetDeviceProvider)();
    } catch (e) {
      // The database survived: say so rather than reload over it.
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.web_forgetDevice_failed)));
    }
  }
}
