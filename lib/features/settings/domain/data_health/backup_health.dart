import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// What the backup health rules read.
class BackupHealthInputs {
  const BackupHealthInputs({
    required this.autoEnabled,
    required this.frequency,
    required this.lastBackupAt,
    required this.lastScheduledFailureAt,
    required this.cloudBackupEnabled,
    required this.lastCloudCopyMissing,
    required this.lastCloudCopyNeedsSignIn,
    required this.copyAccountNeedsSignIn,
    required this.hasCustomLocation,
    required this.syncConfigured,
  });

  final bool autoEnabled;
  final BackupFrequency frequency;
  final DateTime? lastBackupAt;
  final DateTime? lastScheduledFailureAt;
  final bool cloudBackupEnabled;
  final bool lastCloudCopyMissing;

  /// The server refused the last copy.
  final bool lastCloudCopyNeedsSignIn;

  /// The copy's account reads as signed out on this device.
  final bool copyAccountNeedsSignIn;

  /// A backup folder the diver chose. Counted as a copy off this device:
  /// the app cannot tell a NAS or synced folder from a local one.
  final bool hasCustomLocation;

  /// Cloud sync is set up, which keeps a copy of the library off device.
  final bool syncConfigured;
}

/// Backup health per the spec's backup table. Overdue means older than two
/// frequency periods: the OS defers mobile background work and the desktop
/// timer checks hourly, so one period would flicker every cycle.
FeatureHealth evaluateBackupHealth(BackupHealthInputs i, DateTime now) {
  FeatureHealth health(
    HealthLevel level,
    HealthReason reason, {
    DateTime? at,
  }) => FeatureHealth(
    feature: DataFeature.backup,
    level: level,
    reason: reason,
    when: at,
  );

  // Ahead of "automatic backups are off": a diver who backs up by hand would
  // otherwise never be offered the sign-in that gets the copy working.
  final copySignIn =
      i.cloudBackupEnabled &&
      i.lastCloudCopyMissing &&
      (i.lastCloudCopyNeedsSignIn || i.copyAccountNeedsSignIn);

  if (!i.autoEnabled) {
    return health(
      HealthLevel.attention,
      copySignIn ? HealthReason.backupCloudSignIn : HealthReason.backupAutoOff,
    );
  }

  final lastBackup = i.lastBackupAt;
  final failedAt = i.lastScheduledFailureAt;
  final periods = BackupSettings(frequency: i.frequency).frequencyDuration * 2;

  return pickHealth(DataFeature.backup, [
    if (failedAt != null &&
        (lastBackup == null || failedAt.isAfter(lastBackup)))
      health(HealthLevel.failing, HealthReason.backupFailed, at: failedAt),
    if (copySignIn)
      health(HealthLevel.attention, HealthReason.backupCloudSignIn),
    if (lastBackup == null)
      health(HealthLevel.attention, HealthReason.backupNever)
    else if (now.difference(lastBackup) > periods)
      health(HealthLevel.attention, HealthReason.backupOverdue, at: lastBackup),
    if (i.cloudBackupEnabled && i.lastCloudCopyMissing && !copySignIn)
      health(HealthLevel.attention, HealthReason.backupCloudCopyMissing),
    if (!i.cloudBackupEnabled && !i.syncConfigured && !i.hasCustomLocation)
      health(HealthLevel.attention, HealthReason.backupNoOffDeviceCopy),
  ]);
}
