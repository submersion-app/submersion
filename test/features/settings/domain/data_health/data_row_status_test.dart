// Issue #3482: the one-sentence statuses under the Settings > Data rows are
// derived from the same inputs as the health strip, by pure functions.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

FeatureHealth _h(
  DataFeature feature,
  HealthLevel level,
  HealthReason reason, {
  DateTime? when,
}) => FeatureHealth(feature: feature, level: level, reason: reason, when: when);

void main() {
  // Issue #3482 review: Lightroom alone reads healthy, but the row says no
  // copies are kept; a healthy mark beside that would contradict it.
  test('only a photos-off status hides the health mark', () {
    expect(
      const DataRowStatus(DataRowStatusKind.photosOff).showsHealthMark,
      isFalse,
    );
    expect(
      const DataRowStatus(DataRowStatusKind.photosOn).showsHealthMark,
      isTrue,
    );
    expect(
      const DataRowStatus(DataRowStatusKind.backupsLocal).showsHealthMark,
      isTrue,
    );
  });

  final at = DateTime(2026, 10, 18, 9);

  group('backupsRowStatus', () {
    FeatureHealth backup(HealthLevel level, HealthReason reason) =>
        _h(DataFeature.backup, level, reason, when: at);
    final healthy = backup(HealthLevel.healthy, HealthReason.ok);

    DataRowStatus row({
      FeatureHealth? health,
      DateTime? lastBackup,
      LastBackupDestination? destination,
      String? label = 'Google Drive',
    }) => backupsRowStatus(
      health: health ?? healthy,
      lastBackup: lastBackup,
      destination: destination,
      cloudAccountLabel: label,
    );

    test('a failed scheduled backup wins over everything', () {
      final s = row(
        health: backup(HealthLevel.failing, HealthReason.backupFailed),
        lastBackup: at,
        destination: LastBackupDestination.cloud,
      );
      expect((s.kind, s.when), (DataRowStatusKind.backupsFailed, at));
    });

    test('no backup yet', () {
      expect(row().kind, DataRowStatusKind.backupsNever);
    });

    // Issue #3482 review: the row says where the LAST backup went, not where
    // the current settings would send the next one.
    test('a backup that reached the cloud names the account', () {
      final s = row(lastBackup: at, destination: LastBackupDestination.cloud);
      expect(
        (s.kind, s.when, s.name),
        (DataRowStatusKind.backupsCloud, at, 'Google Drive'),
      );
    });

    test('a backup written to the chosen folder says so', () {
      final s = row(lastBackup: at, destination: LastBackupDestination.folder);
      expect((s.kind, s.when), (DataRowStatusKind.backupsFolder, at));
    });

    test('a backup that stayed on the device says so', () {
      final s = row(lastBackup: at, destination: LastBackupDestination.device);
      expect((s.kind, s.when), (DataRowStatusKind.backupsLocal, at));
    });

    test('an exported file or an unknown destination claims no place', () {
      for (final destination in [LastBackupDestination.file, null]) {
        final s = row(lastBackup: at, destination: destination);
        expect(
          (s.kind, s.when),
          (DataRowStatusKind.backupsPlain, at),
          reason: '$destination',
        );
      }
    });

    test('set up is offered only while automatic backups are off', () {
      final off = row(
        health: backup(HealthLevel.attention, HealthReason.backupAutoOff),
        lastBackup: at,
        destination: LastBackupDestination.device,
      );
      final on = row(lastBackup: at, destination: LastBackupDestination.device);
      expect((off.offersSetUp, on.offersSetUp), (true, false));
    });
  });

  group('syncRowStatus', () {
    FeatureHealth sync(HealthLevel level, HealthReason reason) =>
        _h(DataFeature.sync, level, reason, when: at);

    test('paused reasons carry the health for their text', () {
      for (final reason in [
        HealthReason.syncNeedsPassphrase,
        HealthReason.syncAwaitingAdoption,
        HealthReason.syncSignedOut,
        HealthReason.syncFailed,
      ]) {
        final s = syncRowStatus(
          health: sync(HealthLevel.failing, reason),
          lastSync: at,
          peerNames: const ['Eric\'s iPhone'],
        );
        expect(s.kind, DataRowStatusKind.syncAttention, reason: '$reason');
        expect(s.health?.reason, reason);
      }
    });

    test('no provider reads off and offers set up', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.attention, HealthReason.syncOff),
        lastSync: null,
        peerNames: const [],
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.syncOff, true));
    });

    test('a synced custom folder credits the folder service', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.notSetUp, HealthReason.syncCustomFolder),
        lastSync: at,
        peerNames: const [],
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.syncFolder, false));
    });

    test('custom folder on a device-only volume reads off', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.notSetUp, HealthReason.syncCustomFolder),
        lastSync: at,
        peerNames: const [],
        customFolderIsDeviceOnly: true,
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.syncOff, false));
    });

    test('never synced', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.attention, HealthReason.syncNeverSynced),
        lastSync: null,
        peerNames: const [],
      );
      expect(s.kind, DataRowStatusKind.syncNever);
    });

    test('alone, with one peer, with many peers', () {
      final alone = syncRowStatus(
        health: sync(HealthLevel.healthy, HealthReason.ok),
        lastSync: at,
        peerNames: const [],
      );
      final one = syncRowStatus(
        health: sync(HealthLevel.healthy, HealthReason.ok),
        lastSync: at,
        peerNames: const ['Eric\'s iPhone'],
      );
      final many = syncRowStatus(
        health: sync(HealthLevel.healthy, HealthReason.ok),
        lastSync: at,
        peerNames: const ['Eric\'s iPhone', 'Dive Laptop', 'iPad'],
      );
      expect((alone.kind, alone.when), (DataRowStatusKind.syncSynced, at));
      expect(
        (one.kind, one.when, one.name),
        (DataRowStatusKind.syncWithOne, at, 'Eric\'s iPhone'),
      );
      expect(
        (many.kind, many.when, many.count),
        (DataRowStatusKind.syncWithMany, at, 3),
      );
    });

    test('blank peer names are not counted', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.healthy, HealthReason.ok),
        lastSync: at,
        peerNames: const ['', ' '],
      );
      expect(s.kind, DataRowStatusKind.syncSynced);
    });

    test(
      'conflicts, held peers and a long offline spell show the strip line',
      () {
        for (final reason in [
          HealthReason.syncConflicts,
          HealthReason.syncPeersHeld,
          HealthReason.syncOffline,
        ]) {
          final s = syncRowStatus(
            health: sync(HealthLevel.attention, reason),
            lastSync: at,
            peerNames: const ['Eric\'s iPhone'],
          );
          expect(s.kind, DataRowStatusKind.syncAttention, reason: '$reason');
          expect(s.health?.reason, reason);
        }
      },
    );

    test('automatic sync off still reads as in step', () {
      final s = syncRowStatus(
        health: sync(HealthLevel.attention, HealthReason.syncAutoOff),
        lastSync: at,
        peerNames: const ['Eric\'s iPhone'],
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.syncWithOne, false));
    });
  });

  group('photosRowStatus', () {
    test('not set up offers set up', () {
      final s = photosRowStatus(
        health: _h(
          DataFeature.media,
          HealthLevel.notSetUp,
          HealthReason.notSetUp,
        ),
        storeHint: null,
        storeAttachedHere: false,
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.photosOff, true));
    });

    test('attention carries the health', () {
      final h = _h(
        DataFeature.media,
        HealthLevel.attention,
        HealthReason.mediaTransfersPaused,
      );
      final s = photosRowStatus(
        health: h,
        storeHint: 'bucket @ host',
        storeAttachedHere: true,
      );
      expect((s.kind, s.health), (DataRowStatusKind.photosAttention, h));
    });

    test('Lightroom alone is a source, not a place copies are kept', () {
      final s = photosRowStatus(
        health: _h(DataFeature.media, HealthLevel.healthy, HealthReason.ok),
        storeHint: null,
        storeAttachedHere: false,
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.photosOff, true));
    });

    test('healthy names the store', () {
      final s = photosRowStatus(
        health: _h(DataFeature.media, HealthLevel.healthy, HealthReason.ok),
        storeHint: 'bucket @ host',
        storeAttachedHere: true,
      );
      expect(
        (s.kind, s.name, s.offersSetUp),
        (DataRowStatusKind.photosOn, 'bucket @ host', false),
      );
    });
  });

  group('librariesRowStatus', () {
    test('none joined', () {
      final s = librariesRowStatus(
        health: _h(
          DataFeature.sharedLibraries,
          HealthLevel.notSetUp,
          HealthReason.notSetUp,
        ),
        count: 0,
        lastSync: null,
      );
      expect((s.kind, s.offersSetUp), (DataRowStatusKind.librariesNone, false));
    });

    test('attention and failing carry the health', () {
      final h = _h(
        DataFeature.sharedLibraries,
        HealthLevel.failing,
        HealthReason.librariesFailed,
      );
      final s = librariesRowStatus(health: h, count: 2, lastSync: at);
      expect(
        (s.kind, s.health, s.count),
        (DataRowStatusKind.librariesAttention, h, 2),
      );
    });

    test('joined but never synced, and synced', () {
      final healthy = _h(
        DataFeature.sharedLibraries,
        HealthLevel.healthy,
        HealthReason.ok,
      );
      final never = librariesRowStatus(
        health: healthy,
        count: 1,
        lastSync: null,
      );
      final synced = librariesRowStatus(
        health: healthy,
        count: 2,
        lastSync: at,
      );
      expect(
        (never.kind, never.count),
        (DataRowStatusKind.librariesSomeNever, 1),
      );
      expect(
        (synced.kind, synced.count, synced.when),
        (DataRowStatusKind.librariesSome, 2, at),
      );
    });
  });

  group('accountsRowStatus', () {
    test('sign-ins needed win', () {
      final s = accountsRowStatus(
        labels: const ['Google Drive'],
        needSignIn: 2,
      );
      expect((s.kind, s.count), (DataRowStatusKind.accountsNeedSignIn, 2));
    });

    test('none yet', () {
      final s = accountsRowStatus(labels: const [], needSignIn: 0);
      expect(s.kind, DataRowStatusKind.accountsNone);
    });

    test('the roster joins the labels', () {
      final s = accountsRowStatus(
        labels: const ['Google Drive', 'nas.home'],
        needSignIn: 0,
      );
      expect(
        (s.kind, s.name),
        (DataRowStatusKind.accountsListed, 'Google Drive, nas.home'),
      );
    });
  });
}
