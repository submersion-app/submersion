import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart'
    show syncAccountKinds;

/// The "Set up this device" card's state, derived from the features
/// themselves (issue #3482). Null while an input is still loading, so the
/// card never flashes a step as outstanding that is in fact done.
final setUpProgressProvider = Provider.autoDispose<SetUpProgress?>((ref) {
  final groups = ref.watch(accountGroupsProvider);
  final attached = ref.watch(mediaStoreAttachedProvider);
  if (!groups.hasValue || !attached.hasValue) return null;
  final backup = ref.watch(backupSettingsProvider);
  final card = ref.watch(setUpCardPrefsProvider);
  return setUpProgress(
    SetUpInputs(
      accountHere: groups.requireValue.any(
        (g) => syncAccountKinds.contains(g.kind) && g.signedInHere,
      ),
      syncEstablished:
          ref.watch(isSyncEnabledProvider) &&
          ref.watch(lastSyncTimeProvider) != null,
      customFolder: ref.watch(isCloudSyncDisabledByCustomFolderProvider),
      backupsAuto: backup.enabled,
      backupOffDevice:
          backup.cloudBackupEnabled || backup.backupLocation != null,
      photosAttached: attached.requireValue,
      photosSkipped: card.photosSkipped,
      hidden: card.hidden,
    ),
  );
});
