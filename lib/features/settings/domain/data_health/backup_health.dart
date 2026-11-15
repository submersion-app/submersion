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
    this.lastExtraCopyMissing = false,
    this.extraCopyMissingIds = const [],
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

  /// An extra account the last backup should have reached did not get its
  /// copy (#3782).
  final bool lastExtraCopyMissing;

  /// The extra accounts that missed it, so the Backup page marks only their
  /// tiles (#4561). Empty with [lastExtraCopyMissing] set gives one finding
  /// about no account in particular.
  final List<String> extraCopyMissingIds;

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
    String? subjectId,
  }) => FeatureHealth(
    feature: DataFeature.backup,
    level: level,
    reason: reason,
    when: at,
    subjectId: subjectId,
  );

  // Ahead of "automatic backups are off": a diver who backs up by hand would
  // otherwise never be offered the sign-in that gets the copy working.
  final copySignIn =
      i.cloudBackupEnabled &&
      i.lastCloudCopyMissing &&
      (i.lastCloudCopyNeedsSignIn || i.copyAccountNeedsSignIn);

  // Where copies go, which holds whether or not the schedule runs.
  final copyFindings = [
    if (i.cloudBackupEnabled && i.lastCloudCopyMissing && !copySignIn)
      health(HealthLevel.attention, HealthReason.backupCloudCopyMissing),
    // A missing main copy already says the stronger thing.
    if (i.cloudBackupEnabled &&
        i.lastExtraCopyMissing &&
        !i.lastCloudCopyMissing)
      if (i.extraCopyMissingIds.isEmpty)
        health(HealthLevel.attention, HealthReason.backupExtraCopyMissing)
      else
        for (final id in i.extraCopyMissingIds)
          health(
            HealthLevel.attention,
            HealthReason.backupExtraCopyMissing,
            subjectId: id,
          ),
    if (!i.cloudBackupEnabled && !i.syncConfigured && !i.hasCustomLocation)
      health(HealthLevel.attention, HealthReason.backupNoOffDeviceCopy),
  ];

  // The headline stays "off" (or the copy's sign-in); failed, overdue and
  // never describe a schedule that is not running, so they are left out.
  // All attention, so the first (the sign-in, else "off") is the headline.
  if (!i.autoEnabled) {
    return pickHealth(DataFeature.backup, [
      if (copySignIn)
        health(HealthLevel.attention, HealthReason.backupCloudSignIn),
      health(HealthLevel.attention, HealthReason.backupAutoOff),
      ...copyFindings,
    ]);
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
    ...copyFindings,
  ]);
}
