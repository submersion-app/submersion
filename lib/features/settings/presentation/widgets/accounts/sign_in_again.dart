import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_confirm_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_now_action.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The [signInAgain] that is running: two OAuth flows at once would race.
Object? _attempt;

/// How long a sign-in may hold [_attempt]. The macOS loopback flow has no
/// timeout and no cancel dialog, so one abandoned in the browser never
/// returns, and the button must not stay dead until the app restarts. An
/// attempt past this is retired: if it does finish, it retries nothing.
const _abandonedAfter = Duration(minutes: 5);

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
  if (_attempt != null) return;
  final attempt = _attempt = Object();
  bool current() => identical(_attempt, attempt);
  final abandoned = Timer(_abandonedAfter, () {
    if (current()) _attempt = null;
  });
  try {
    // Read before signing in: the sign-in refreshes both.
    final container = ProviderScope.containerOf(context, listen: false);
    final AccountGroup? syncGroup;
    final AccountGroup? copyGroup;
    try {
      syncGroup = (await container.read(accountGroupsProvider.future)).syncing;
      copyGroup = backupCopyGroupOf(await readBackupCopyTarget(container));
    } on Object {
      if (context.mounted) showAccountsLoadFailed(context, ref);
      return;
    }
    final copyMissing = container
        .read(backupSettingsProvider)
        .lastCloudCopyMissing;
    if (!context.mounted) return;

    final signedIn = await _signIn(context, ref, group, isCurrent: current);
    if (!signedIn || !current() || !context.mounted) return;

    if (syncGroup?.key == group.key) await runSyncNow(context, ref);
    if (copyMissing && copyGroup?.key == group.key && context.mounted) {
      await ref.read(backupOperationProvider.notifier).performBackup();
    }
  } finally {
    abandoned.cancel();
    if (current()) _attempt = null;
  }
}

/// Signs in, asking again for as long as the diver keeps picking another
/// account and chooses to try once more. True when signed in to [group].
Future<bool> _signIn(
  BuildContext context,
  WidgetRef ref,
  AccountGroup group, {
  required bool Function() isCurrent,
}) async {
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
    if (!isCurrent() || !context.mounted) return false;
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
}) {
  final l10n = context.l10n;
  return confirmAccountAction(
    context,
    title: l10n.settings_accounts_differentAccount_title,
    paragraphs: [
      l10n.settings_accounts_differentAccount_body(expected, signedIn),
      l10n.settings_accounts_differentAccount_nothingSynced(signedIn),
    ],
    usages: const [],
    action: l10n.settings_accounts_signInAgain,
    cancel: l10n.settings_setUpDevice_notNow,
  );
}
