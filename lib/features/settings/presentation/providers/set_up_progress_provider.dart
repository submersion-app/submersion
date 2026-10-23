import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// The "Set up this device" card's state, derived from the features
/// themselves (issue #3482). Null only while the attach state loads, so the
/// card never flashes a step as outstanding that is in fact done.
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
  final photosAttached = attached.hasError ? false : attached.value ?? false;
  final syncSelected = ref.watch(isSyncEnabledProvider);
  final backup = ref.watch(backupSettingsProvider);
  final card = ref.watch(setUpCardPrefsProvider);
  return setUpProgress(
    SetUpInputs(
      accountHere:
          syncSelected || backup.copyAccountId != null || photosAttached,
      syncEstablished: syncSelected && ref.watch(lastSyncTimeProvider) != null,
      customFolder: ref.watch(isCloudSyncDisabledByCustomFolderProvider),
      backupsAuto: backup.enabled,
      // A copy that follows sync goes nowhere while sync names no account.
      backupOffDevice:
          (backup.cloudBackupEnabled &&
              (backup.copyAccountId != null || syncSelected)) ||
          backup.backupLocation != null,
      photosAttached: photosAttached,
      photosSkipped: card.photosSkipped,
      hidden: card.hidden,
    ),
  );
});
