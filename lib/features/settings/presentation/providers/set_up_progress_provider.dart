import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// The "Set up this device" card's state, derived from the features
/// themselves (issue #3482). Null while the attach state, the storage
/// location, the restored sync account or the pinned copy's roster check is
/// still loading, so the card does not show a done step as outstanding.
///
/// It probes no account: the card sits on the Settings root and the Data
/// page, which never ask an account for its sign-in state (spec 7.2). An
/// account is in use here when a feature names it; whether it still needs a
/// sign-in is the pending sign-in item's job.
final setUpProgressProvider = Provider.autoDispose<SetUpProgress?>((ref) {
  final attached = ref.watch(mediaStoreAttachedProvider);
  // A failed read is not attached: the card still shows, with the photo
  // step outstanding, rather than vanishing with its pending items.
  if (attached.isLoading && !attached.hasValue) return null;
  if (!ref.watch(storageConfigLoadedProvider)) return null;
  if (ref.watch(restoreLastProviderProvider).isLoading) return null;

  // The pin counts only while the copy is on, and only for a row the roster
  // still has; an unreadable roster counts, as the backup itself copies then.
  final pinned = ref.watch(pinnedCopyAccountIdProvider);
  final onRoster = pinned == null
      ? null
      : ref.watch(copyRowOnRosterProvider(pinned));
  if (onRoster != null && onRoster.isLoading && !onRoster.hasValue) {
    return null;
  }
  final pinnedRowHere =
      onRoster != null && (onRoster.value ?? onRoster.hasError);

  final photosAttached = attached.hasError ? false : attached.value ?? false;
  final syncSelected = ref.watch(isSyncEnabledProvider);
  final (backupsAuto, cloudCopy, backupFolder) = ref.watch(
    backupSettingsProvider.select(
      (s) => (s.enabled, s.cloudBackupEnabled, s.backupLocation != null),
    ),
  );
  final card = ref.watch(setUpCardPrefsNotifierProvider);
  return setUpProgress(
    SetUpInputs(
      accountHere: syncSelected || pinnedRowHere || photosAttached,
      syncEstablished:
          syncSelected &&
          ref.watch(lastSyncTimeProvider.select((t) => t != null)),
      // On Android a custom folder is a device volume no service keeps in
      // step, so it settles nothing.
      customFolder:
          ref.watch(isCloudSyncDisabledByCustomFolderProvider) &&
          !ref.watch(syncFolderIsDeviceOnlyProvider),
      backupsAuto: backupsAuto,
      // A copy that follows sync goes nowhere while sync names no account.
      backupOffDevice:
          (cloudCopy && (pinned != null ? pinnedRowHere : syncSelected)) ||
          backupFolder,
      photosAttached: photosAttached,
      photosSkipped: card.photosSkipped,
      hidden: card.hidden,
    ),
  );
});
