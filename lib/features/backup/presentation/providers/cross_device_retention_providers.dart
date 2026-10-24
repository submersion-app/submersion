import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

/// Whether "count backups from all devices" is offered (issue #3503): only
/// while backups are copied to a cloud folder, the only folder devices share.
final crossDeviceRetentionAvailableProvider = Provider.autoDispose<bool>(
  (ref) => switch (ref.watch(backupCopyTargetProvider).value) {
    CopyToAccount() => true,
    CopyFollowsSync(:final group) => group != null,
    _ => false,
  },
);

/// Whether the switch is on for the folder backups go to now. A switch
/// confirmed for another account reads as off.
final crossDeviceRetentionActiveProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  ref.watch(
    backupSettingsProvider.select((s) => s.crossDeviceRetentionAccount),
  );
  return ref.watch(backupServiceProvider).crossDeviceRetentionActive();
});

/// The account backups are copied to now, so the folder footprint counts
/// only copies in that folder.
final backupCopyAccountIdProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(backupServiceProvider).cloudCopyAccountId(),
);
