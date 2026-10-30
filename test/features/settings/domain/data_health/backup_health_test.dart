import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/domain/data_health/backup_health.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);

  BackupHealthInputs inputs({
    bool autoEnabled = true,
    BackupFrequency frequency = BackupFrequency.weekly,
    DateTime? lastBackupAt,
    DateTime? lastScheduledFailureAt,
    bool cloudBackupEnabled = true,
    bool lastCloudCopyMissing = false,
    bool lastCloudCopyNeedsSignIn = false,
    bool copyAccountNeedsSignIn = false,
    bool hasCustomLocation = false,
    bool syncConfigured = false,
    bool noBackup = false,
  }) => BackupHealthInputs(
    autoEnabled: autoEnabled,
    frequency: frequency,
    lastBackupAt: noBackup
        ? null
        : lastBackupAt ?? now.subtract(const Duration(hours: 3)),
    lastScheduledFailureAt: lastScheduledFailureAt,
    cloudBackupEnabled: cloudBackupEnabled,
    lastCloudCopyMissing: lastCloudCopyMissing,
    lastCloudCopyNeedsSignIn: lastCloudCopyNeedsSignIn,
    copyAccountNeedsSignIn: copyAccountNeedsSignIn,
    hasCustomLocation: hasCustomLocation,
    syncConfigured: syncConfigured,
  );

  void expectHealth(
    FeatureHealth health,
    HealthLevel level,
    HealthReason reason, {
    DateTime? when,
  }) {
    expect(health.feature, DataFeature.backup);
    expect(health.level, level);
    expect(health.reason, reason);
    if (when != null) expect(health.when, when);
  }

  test('auto off is attention autoOff even after a failure', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(
          autoEnabled: false,
          lastScheduledFailureAt: now.subtract(const Duration(hours: 1)),
          lastBackupAt: now.subtract(const Duration(days: 2)),
        ),
        now,
      ),
      HealthLevel.attention,
      HealthReason.backupAutoOff,
    );
  });

  test('failure newer than last success is failing', () {
    final failedAt = now.subtract(const Duration(hours: 1));
    expectHealth(
      evaluateBackupHealth(
        inputs(
          lastScheduledFailureAt: failedAt,
          lastBackupAt: now.subtract(const Duration(days: 2)),
        ),
        now,
      ),
      HealthLevel.failing,
      HealthReason.backupFailed,
      when: failedAt,
    );
  });

  test('failure older than last success is ignored', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(
          lastScheduledFailureAt: now.subtract(const Duration(days: 3)),
          lastBackupAt: now.subtract(const Duration(hours: 1)),
        ),
        now,
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('never backed up is attention never', () {
    expectHealth(
      evaluateBackupHealth(inputs(noBackup: true), now),
      HealthLevel.attention,
      HealthReason.backupNever,
    );
  });

  test('weekly backup 13 days old is healthy', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(lastBackupAt: now.subtract(const Duration(days: 13))),
        now,
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('weekly backup 15 days old is overdue', () {
    final last = now.subtract(const Duration(days: 15));
    expectHealth(
      evaluateBackupHealth(inputs(lastBackupAt: last), now),
      HealthLevel.attention,
      HealthReason.backupOverdue,
      when: last,
    );
  });

  test('daily backup 3 days old is overdue', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(
          frequency: BackupFrequency.daily,
          lastBackupAt: now.subtract(const Duration(days: 3)),
        ),
        now,
      ),
      HealthLevel.attention,
      HealthReason.backupOverdue,
    );
  });

  test('cloud copy missing is attention', () {
    expectHealth(
      evaluateBackupHealth(inputs(lastCloudCopyMissing: true), now),
      HealthLevel.attention,
      HealthReason.backupCloudCopyMissing,
    );
  });

  group('a cloud copy that needs a sign-in', () {
    BackupHealthInputs missing({
      bool autoEnabled = true,
      bool flag = true,
      bool accountSignedOut = false,
      DateTime? lastBackupAt,
      DateTime? lastScheduledFailureAt,
      bool lastCloudCopyMissing = true,
    }) => inputs(
      autoEnabled: autoEnabled,
      lastCloudCopyMissing: lastCloudCopyMissing,
      lastCloudCopyNeedsSignIn: flag,
      copyAccountNeedsSignIn: accountSignedOut,
      lastBackupAt: lastBackupAt,
      lastScheduledFailureAt: lastScheduledFailureAt,
    );

    test('reads as signIn from the stored flag', () {
      expectHealth(
        evaluateBackupHealth(missing(), now),
        HealthLevel.attention,
        HealthReason.backupCloudSignIn,
      );
    });

    test('reads as signIn from the account being signed out', () {
      expectHealth(
        evaluateBackupHealth(missing(flag: false, accountSignedOut: true), now),
        HealthLevel.attention,
        HealthReason.backupCloudSignIn,
      );
    });

    test('beats automatic backups being off', () {
      expectHealth(
        evaluateBackupHealth(missing(autoEnabled: false), now),
        HealthLevel.attention,
        HealthReason.backupCloudSignIn,
      );
    });

    test('beats an overdue backup', () {
      expectHealth(
        evaluateBackupHealth(
          missing(lastBackupAt: now.subtract(const Duration(days: 60))),
          now,
        ),
        HealthLevel.attention,
        HealthReason.backupCloudSignIn,
      );
    });

    test('a failed backup still beats it', () {
      final failedAt = now.subtract(const Duration(hours: 1));
      expectHealth(
        evaluateBackupHealth(missing(lastScheduledFailureAt: failedAt), now),
        HealthLevel.failing,
        HealthReason.backupFailed,
      );
    });

    test('needs a missing copy', () {
      expect(
        evaluateBackupHealth(
          missing(lastCloudCopyMissing: false, accountSignedOut: true),
          now,
        ).reason,
        isNot(HealthReason.backupCloudSignIn),
      );
    });

    test('needs the cloud copy to be on', () {
      expect(
        evaluateBackupHealth(
          inputs(
            cloudBackupEnabled: false,
            lastCloudCopyMissing: true,
            lastCloudCopyNeedsSignIn: true,
          ),
          now,
        ).reason,
        isNot(HealthReason.backupCloudSignIn),
      );
    });
  });

  test('no cloud, no sync, no custom location is noOffDeviceCopy', () {
    expectHealth(
      evaluateBackupHealth(inputs(cloudBackupEnabled: false), now),
      HealthLevel.attention,
      HealthReason.backupNoOffDeviceCopy,
    );
  });

  test('custom location counts as off device', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(cloudBackupEnabled: false, hasCustomLocation: true),
        now,
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('sync configured counts as off device', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(cloudBackupEnabled: false, syncConfigured: true),
        now,
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('failing outranks overdue', () {
    expectHealth(
      evaluateBackupHealth(
        inputs(
          lastBackupAt: now.subtract(const Duration(days: 30)),
          lastScheduledFailureAt: now.subtract(const Duration(days: 1)),
        ),
        now,
      ),
      HealthLevel.failing,
      HealthReason.backupFailed,
    );
  });

  group('pickHealth', () {
    test('empty list is healthy ok', () {
      final h = pickHealth(DataFeature.sync, const []);
      expect(h.level, HealthLevel.healthy);
      expect(h.reason, HealthReason.ok);
      expect(h.feature, DataFeature.sync);
    });

    test('ties go to the earliest candidate', () {
      const a = FeatureHealth(
        feature: DataFeature.sync,
        level: HealthLevel.attention,
        reason: HealthReason.syncConflicts,
      );
      const b = FeatureHealth(
        feature: DataFeature.sync,
        level: HealthLevel.attention,
        reason: HealthReason.syncAutoOff,
      );
      expect(pickHealth(DataFeature.sync, const [a, b]), a);
    });
  });
}
