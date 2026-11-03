import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/features/settings/presentation/widgets/web/web_forget_device_action.dart';
import 'package:submersion/features/settings/presentation/widgets/web/web_storage_text.dart';
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
          subtitle: status == null
              ? null
              : Text(describeWebStorage(l10n, status)),
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
          onTap: () => confirmAndForgetDevice(context, ref),
        ),
      ],
    );
  }
}
