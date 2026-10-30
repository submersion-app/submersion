import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_now_action.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Set while [signInAgain] runs: two OAuth flows at once would race.
bool _running = false;

/// Runs [group]'s sign-in from a sync or backup error, then retries what the
/// account was failing (issue #3811): a sync when sync uses it, then a backup
/// when the copy goes there and is missing, so one tap clears both errors.
///
/// Signing in removes the line that offered this, so [context] and [ref] must
/// come from a widget that stays: the Data strip, the Cloud Sync page. If the
/// diver leaves it mid sign-in, the retry is skipped and the next automatic
/// sync picks it up.
Future<void> signInAgain(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group,
) async {
  if (_running) return;
  _running = true;
  try {
    // Read before signing in: the sign-in refreshes both.
    final syncGroup = (await ref.read(accountGroupsProvider.future)).syncing;
    final copyGroup = backupCopyGroupOf(
      await ref.read(backupCopyTargetProvider.future),
    );
    final copyMissing = ref.read(backupSettingsProvider).lastCloudCopyMissing;
    if (!context.mounted) return;

    if (!await _signIn(context, ref, group) || !context.mounted) return;

    if (syncGroup?.key == group.key) {
      // A failure on record is another account's if sync uses another one.
      await ref
          .read(syncFailureProvider.notifier)
          .clearFor(ref.read(cloudStorageProviderProvider)?.providerId);
      await ref.read(syncStateProvider.notifier).refreshState();
      if (context.mounted) await runSyncNow(context, ref);
    }
    if (copyMissing && copyGroup?.key == group.key && context.mounted) {
      await ref.read(backupOperationProvider.notifier).performBackup();
    }
  } finally {
    _running = false;
  }
}

/// Signs in, asking again for as long as the diver keeps picking another
/// account and chooses to try once more. True when signed in to [group].
Future<bool> _signIn(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group,
) async {
  while (true) {
    if (!context.mounted) return false;
    String? differentAccount;
    final signedIn = await signInToGroup(
      context,
      ref,
      group,
      expectedAccount: group.identifier,
      onDifferentAccount: (account) => differentAccount = account,
    );
    final other = differentAccount;
    if (other == null) return signedIn;
    if (!context.mounted) return false;
    final tryAgain = await _showDifferentAccountDialog(
      context,
      expected: group.identifier ?? '',
      signedIn: other,
    );
    if (!tryAgain) return false;
  }
}

Future<bool> _showDifferentAccountDialog(
  BuildContext context, {
  required String expected,
  required String signedIn,
}) async {
  final l10n = context.l10n;
  final tryAgain = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.settings_accounts_differentAccount_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_accounts_differentAccount_body(expected, signedIn),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settings_accounts_differentAccount_nothingSynced(signedIn),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.settings_setUpDevice_notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.settings_accounts_signInAgain),
        ),
      ],
    ),
  );
  return tryAgain ?? false;
}
