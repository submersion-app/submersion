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
  // Both settings the answer reads: turning cloud backup off turns it off.
  ref.watch(
    backupSettingsProvider.select(
      (s) => (s.crossDeviceRetentionAccount, s.cloudBackupEnabled),
    ),
  );
  return ref.watch(backupServiceProvider).crossDeviceRetentionActive();
});

/// Whether a cross-device change (turning the switch on, or lowering "Keep"
/// while it is on) is listing, asking or pruning. One runs at a time.
class CrossDeviceRetentionBusy extends Notifier<bool> {
  @override
  bool build() => false;

  /// A no-op once the scope is gone (the app closing mid-prune).
  void set(bool value) {
    if (ref.mounted) state = value;
  }
}

final crossDeviceRetentionBusyProvider =
    NotifierProvider<CrossDeviceRetentionBusy, bool>(
      CrossDeviceRetentionBusy.new,
    );
