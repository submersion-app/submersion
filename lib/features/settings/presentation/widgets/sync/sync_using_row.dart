import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The kinds sync can run on.
const syncAccountKinds = {
  AccountKind.icloud,
  AccountKind.googledrive,
  AccountKind.dropbox,
  AccountKind.s3,
  AccountKind.webdav,
};

/// "Using: {account}" with Change, at the top of Sync between devices (spec
/// sections 3 and 8.1); "Not set up" with Set up when sync has no account;
/// and, with the database in a custom folder, why sync is off and where to
/// change that.
class SyncUsingRow extends ConsumerWidget {
  const SyncUsingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (ref.watch(isCloudSyncDisabledByCustomFolderProvider)) {
      return ListTile(
        key: const Key('sync-using-custom-folder'),
        leading: const Icon(Icons.folder_outlined),
        title: Text(l10n.settings_sync_offCustomFolder),
        subtitle: Text(l10n.settings_data_databaseStorage),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushSettingsPage('/settings/storage'),
      );
    }

    final current = currentSyncGroup(
      ref.watch(accountGroupsProvider).value ?? const [],
    );
    final selected = ref.watch(selectedCloudProviderTypeProvider);

    Future<void> change() async {
      // The account sync uses decides the switch warning and the departure
      // record, so wait for the list rather than read a value still loading.
      final AccountGroup? current;
      try {
        current = currentSyncGroup(
          await ref.read(accountGroupsProvider.future),
        );
      } on Object {
        return;
      }
      if (!context.mounted) return;
      final choice = await showAccountSheet(
        context,
        allowedKinds: syncAccountKinds,
        currentKey: current?.key,
        consequenceOf: (c) =>
            syncSwitchConsequence(context, ref, c, current: current),
      );
      if (choice == null || !context.mounted) return;
      await useAccountForSync(context, ref, choice, current: current);
    }

    if (current == null && selected == null) {
      return ListTile(
        key: const Key('sync-using-not-set-up'),
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(l10n.settings_sync_notSetUp),
        subtitle: TileSubtitleAction(
          label: l10n.settings_data_setUp,
          semanticsLabel: l10n.settings_data_setUpFeature(
            l10n.settings_sync_title,
          ),
          onPressed: change,
        ),
      );
    }

    // A selection whose roster row has not been derived yet still names its
    // provider.
    final label = current?.label ?? providerDisplayName(context, selected!);
    return ListTile(
      key: const Key('sync-using'),
      leading: Icon(
        accountKindIcon(
          current?.kind ?? AccountKind.fromCloudProviderType(selected!),
        ),
      ),
      title: Text(l10n.settings_sync_using(label)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The sync row's own state: another device's photos folder on the
          // server does not make sync here "not signed in".
          if (current != null)
            Text(
              accountStateText(
                l10n,
                current.statusOf(current.syncRowHere?.id) ?? current.status,
              ),
            ),
          TileSubtitleAction(
            actionKey: const Key('sync-using-change'),
            label: l10n.settings_sync_change,
            onPressed: change,
          ),
        ],
      ),
    );
  }
}
