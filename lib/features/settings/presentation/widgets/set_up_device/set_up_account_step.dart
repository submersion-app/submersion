import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Step 1, "Where should Submersion keep your data?" (issue #3482, spec
/// 6.4): the account sheet inline, the accounts signed in here first. A
/// choice is held for the next steps and writes nothing: no feature is
/// turned on here.
class SetUpAccountStep extends ConsumerWidget {
  const SetUpAccountStep({
    super.key,
    required this.navigation,
    this.consequenceOf,
    this.onRestoreFile,
  });

  final SetUpStepNavigation navigation;

  /// What choosing an account will do to sync, shown before the choice is
  /// taken. Defaults to the Sync page's own switch warning.
  final String? Function(AccountGroup choice)? consequenceOf;

  /// Restores from a backup file instead. Defaults to Backups' Restore from
  /// a file.
  final Future<void> Function()? onRestoreFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final flow = ref.read(setUpFlowProvider.notifier);
    final chosen = ref.watch(setUpFlowProvider);
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    // Run again, the step starts from the account sync already uses.
    final current = currentSyncGroup(groups);
    final account = chosen ?? current;
    final host = navigation.host;
    return SetUpStepScaffold(
      title: l10n.settings_setUpDevice_account_title,
      // In the wizard the first step has a step before it, and Not now
      // moves on without an account (spec 6.6).
      backLabel: host.inWizard
          ? l10n.common_action_back
          : l10n.settings_setUpDevice_notNow,
      onBack: navigation.onBack,
      secondary: host.inWizard
          ? TextButton(
              onPressed: navigation.onNotNow,
              child: Text(l10n.settings_setUpDevice_notNow),
            )
          : null,
      primaryLabel: l10n.settings_setUpDevice_next,
      onPrimary: account == null
          ? null
          : () {
              flow.choose(account);
              navigation.onNext();
            },
      children: [
        AccountChooser(
          embedded: true,
          offerHints: true,
          signedInFirst: true,
          allowedKinds: syncAccountKinds,
          currentKey: account?.key,
          consequenceOf:
              consequenceOf ??
              (choice) =>
                  syncSwitchConsequence(context, ref, choice, current: current),
          onChosen: (choice) {
            if (choice is ChoseAccount) {
              flow.choose(choice.group);
              navigation.onNext();
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settings_setUpDevice_account_note,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        // First run offers its own Restore a backup file instead.
        if (host != SetUpHost.firstRun)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onRestoreFile ?? () => restoreFromFile(context, ref),
              child: Text(l10n.settings_setUpDevice_account_backupFile),
            ),
          ),
      ],
    );
  }
}
