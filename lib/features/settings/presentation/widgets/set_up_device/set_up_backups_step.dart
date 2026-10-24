import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_auto_row.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_row.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';

/// Step 3, "A backup that survives a lost device" (issue #3482, spec 6.4):
/// automatic backups and a copy in the flow's account, both on. Nothing is
/// written until Next, so Back and Not now leave Backups as they were.
class SetUpBackupsStep extends ConsumerStatefulWidget {
  const SetUpBackupsStep({super.key, required this.navigation});

  final SetUpStepNavigation navigation;

  @override
  ConsumerState<SetUpBackupsStep> createState() => _SetUpBackupsStepState();
}

class _SetUpBackupsStepState extends ConsumerState<SetUpBackupsStep> {
  bool _auto = true;
  bool _copy = true;
  bool _busy = false;
  String? _line;

  /// Writes the two choices, keeping the schedule: the copy follows sync
  /// when [account] is the account sync uses, and is pinned to it otherwise.
  Future<void> _next(AccountGroup? account, AccountGroup? syncGroup) async {
    setState(() {
      _busy = true;
      _line = null;
    });
    var applied = false;
    try {
      // The copy first: it is the write that can be refused, and a refusal
      // must leave automatic backups as they were.
      applied =
          account == null ||
          await applyBackupCopyChoice(
            ref,
            _copy ? ChoseAccount(account) : const ChoseNone(),
            syncGroup: syncGroup,
          );
      if (applied) {
        await ref.read(backupSettingsProvider.notifier).setEnabled(_auto);
      }
    } on Object {
      applied = false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (applied) {
      widget.navigation.onNext();
    } else if (account != null) {
      setState(
        () => _line = context.l10n.settings_accounts_signInTo(account.label),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final syncGroup = groups.syncing;
    final account = ref.watch(setUpFlowProvider) ?? syncGroup;
    final settings = ref.watch(backupSettingsProvider);
    final device = deviceKindOf(context);
    final frequency = backupFrequencyLabel(l10n, settings.frequency);
    final textTheme = Theme.of(context).textTheme;
    return SetUpStepScaffold(
      title: l10n.settings_setUpDevice_backups_title(deviceKindArg(device)),
      intro: l10n.settings_setUpDevice_backups_intro,
      backLabel: l10n.common_action_back,
      onBack: widget.navigation.onBack,
      primaryLabel: l10n.settings_setUpDevice_next,
      onPrimary: () => _next(account, syncGroup),
      busy: _busy,
      secondary: TextButton(
        onPressed: _busy ? null : widget.navigation.onNotNow,
        child: Text(l10n.settings_setUpDevice_notNow),
      ),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.schedule),
          title: Text(l10n.settings_backups_auto),
          subtitle: Text(
            device == DeviceKind.computer
                ? l10n.settings_setUpDevice_backups_autoDetailDesktop(
                    frequency,
                    settings.retentionCount,
                  )
                : l10n.settings_setUpDevice_backups_autoDetail(
                    frequency,
                    settings.retentionCount,
                  ),
          ),
          value: _auto,
          onChanged: _busy ? null : (v) => setState(() => _auto = v),
        ),
        if (account != null)
          SwitchListTile(
            secondary: Icon(accountKindIcon(account.kind)),
            title: Text(l10n.settings_setUpDevice_backups_copy(account.label)),
            subtitle: account.key == syncGroup?.key
                ? Text(l10n.settings_backups_copySameAsSync)
                : null,
            value: _copy,
            onChanged: _busy ? null : (v) => setState(() => _copy = v),
          )
        else
          ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l10n.settings_setUpDevice_backups_noAccount),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.pushSettingsPage('/settings/backup'),
                child: Text(l10n.settings_setUpDevice_backups_openBackups),
              ),
            ),
          ),
        if (_line != null) ...[
          const SizedBox(height: 8),
          Text(
            _line!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.settings_setUpDevice_backups_note,
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}
