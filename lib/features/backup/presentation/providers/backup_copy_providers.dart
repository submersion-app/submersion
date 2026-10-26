import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_sync_providers.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Where the backup copy goes on this device (spec section 8.2).
sealed class BackupCopyTarget {
  const BackupCopyTarget();
}

/// The copy goes to whichever account sync uses; [group] is null when sync
/// has no account here.
final class CopyFollowsSync extends BackupCopyTarget {
  const CopyFollowsSync(this.group);
  final AccountGroup? group;
}

/// The copy goes to [row], the sync-role row of [group].
final class CopyToAccount extends BackupCopyTarget {
  const CopyToAccount(this.group, this.row);
  final AccountGroup group;
  final ConnectedAccount row;
}

/// The copy was pinned to a row the roster no longer has. The preference is
/// kept: switching the copy elsewhere is the diver's choice to make.
final class CopyAccountGone extends BackupCopyTarget {
  const CopyAccountGone(this.accountId);
  final String accountId;
}

/// No copy off this device.
final class NoCopy extends BackupCopyTarget {
  const NoCopy();
}

/// The row the copy is pinned to while the copy is on; null while it
/// follows sync or is off. A pin left from before the copy was turned off
/// never counts.
final pinnedCopyAccountIdProvider = Provider<String?>(
  (ref) => ref.watch(
    backupSettingsProvider.select(
      (s) => s.cloudBackupEnabled && s.copyAccountKind != null
          ? s.copyAccountId
          : null,
    ),
  ),
);

/// Reads the account groups, which probe every account, so only the
/// Backups page watches it.
final backupCopyTargetProvider = FutureProvider.autoDispose<BackupCopyTarget>((
  ref,
) async {
  final (enabled, accountId) = ref.watch(
    backupSettingsProvider.select(
      (s) => (s.cloudBackupEnabled, s.copyAccountId),
    ),
  );
  if (!enabled) return const NoCopy();
  // With the database in a custom folder, sync has no provider here, so a
  // copy that follows it goes nowhere.
  final syncOff = ref.watch(isCloudSyncDisabledByCustomFolderProvider);
  final groups = await ref.watch(accountGroupsProvider.future);
  if (accountId == null) {
    return CopyFollowsSync(syncOff ? null : groups.syncing);
  }
  final group = groups.holding(accountId);
  final row = group?.rows.where((r) => r.id == accountId).firstOrNull;
  if (group == null || row == null) return CopyAccountGone(accountId);
  return CopyToAccount(group, row);
}, retry: (_, _) => null);

/// Whether the roster still has the row [id]. Follows removals and syncs.
final copyRowOnRosterProvider = FutureProvider.family<bool, String>((
  ref,
  id,
) async {
  final repository = ref.watch(connectedAccountsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchAccountsChanges());
  return await repository.getById(id) != null;
}, retry: (_, _) => null);

/// The provider the backup service copies through, lists and restores from.
///
/// Following sync (or with the copy off, so history still lists the sync
/// folder's backups as it always has) it is sync's own provider. Pinned to a
/// row, it is built the way sync builds one, through the row's
/// [SyncCapable] adapter, from the stored id and kind alone: waiting for the
/// roster here would copy through the wrong account while it loads. A row
/// the roster no longer has (removed, perhaps on another device, with its
/// keys still in this keychain), or has not confirmed yet, resolves to no
/// provider, so nothing is copied there and the backup reports its copy
/// missing; it never falls back to the sync account.
final backupCopyProviderProvider = Provider<CloudStorageProvider?>((ref) {
  final accountId = ref.watch(pinnedCopyAccountIdProvider);
  final kind = ref.watch(
    backupSettingsProvider.select((s) => s.copyAccountKind),
  );
  if (accountId == null || kind == null) {
    return ref.watch(cloudStorageProviderProvider);
  }
  // Nothing is copied until the roster confirms the row, so an account
  // removed elsewhere gets no copy while the lookup runs; this rebuilds once
  // it lands. An unreadable roster copies, as in the background: a
  // database hiccup costs a copy nothing.
  final onRoster = ref.watch(copyRowOnRosterProvider(accountId));
  final unreadable = onRoster.hasError && !onRoster.hasValue;
  if (!unreadable && onRoster.value != true) return null;
  final raw = ref
      .watch(accountProviderRegistryProvider)
      .capabilityFor<SyncCapable>(kind)
      ?.syncProvider(accountRowReference(accountId, kind));
  if (raw == null) return null;
  return wrapForLibrary(raw, ref.watch(encryptionKeyNotifierProvider));
});
