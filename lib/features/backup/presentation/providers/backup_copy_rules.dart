import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_sync_providers.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// What Stop syncing does to the backup copy (spec section 8.1), read
/// before sync is torn down.
///
/// A copy that follows sync is pinned to the row sync was using, so it keeps
/// going to the same place; [copyStops] is true only when that row cannot be
/// read, and the confirmation then says the copy stops. A copy that is off,
/// or pinned to an account, is untouched.
Future<({ConnectedAccount? pinTo, bool copyStops})> backupCopyOnSyncStop(
  ProviderContainer container,
) async {
  final settings = container.read(backupSettingsProvider);
  if (!settings.cloudBackupEnabled || settings.copyAccountId != null) {
    return (pinTo: null, copyStops: false);
  }
  final type = container.read(selectedCloudProviderTypeProvider);
  String? id;
  try {
    id = await container.read(syncRepositoryProvider).getSyncAccountId();
  } on Object {
    id = null;
  }
  if (type == null || id == null) return (pinTo: null, copyStops: true);
  return (
    pinTo: accountRowReference(id, AccountKind.fromCloudProviderType(type)),
    copyStops: false,
  );
}

/// Whether signing out of, or removing, [group] takes the backup copy with
/// it: a copy that follows sync goes with the account sync runs on here
/// ([runsSync]), and a pinned copy goes with the account it is pinned to.
bool backupCopyGoesWith(
  BackupSettings settings,
  AccountGroup group, {
  required bool runsSync,
}) {
  if (!settings.cloudBackupEnabled) return false;
  final pinned = settings.copyAccountId;
  return pinned == null ? runsSync : group.rows.any((r) => r.id == pinned);
}
