import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';

void main() {
  const thisDevice = '9f8e7d6c-1111-2222-3333-444455556666';
  const otherDevice = '0a1b2c3d-1111-2222-3333-444455556666';

  group('buildBackupFilename', () {
    test('keeps the historic prefix and extension', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      // Several call sites match on the prefix (cloud listing, plaintext
      // cleanup) and on the extension. Attribution goes between them so none
      // of that has to change.
      expect(name, startsWith('submersion_backup_'));
      expect(name, endsWith('.db'));
      expect(name, contains('2026-08-31_121314'));
    });

    test('carries the device tag in the name, not just the record', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      // The whole point: an orphan is a file whose record is gone, so
      // attribution stored in the record is exactly the missing information.
      expect(backupDeviceTagFromFilename(name), isNotNull);
    });

    test('produces a filesystem-safe tag', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: 'weird/id with spaces:and*chars',
      );

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(' ')));
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('*')));
    });

    test('the tag is 64 bits wide', () {
      // Pinned because the width is unmigratable. The moment an attributed
      // backup exists in a shared folder its name has to keep parsing, so the
      // choice is made once. At 8 hex digits two devices in one folder could
      // collide and one would be classified as the other, which is exactly the
      // deletion this module refuses to allow.
      expect(deviceTag(thisDevice), matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(deviceTag(thisDevice), isNot(deviceTag(otherDevice)));
    });

    test('the same device always produces the same tag', () {
      final a = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );
      final b = buildBackupFilename(
        timestamp: '2026-09-01_010203',
        deviceId: thisDevice,
      );

      expect(backupDeviceTagFromFilename(a), backupDeviceTagFromFilename(b));
    });
  });

  group('backupDeviceTagFromFilename', () {
    test('reads the tag back from a name this app wrote', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      expect(backupDeviceTagFromFilename(name), deviceTag(thisDevice));
    });

    test('reads a tag from the encrypted variant too', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      ).replaceAll('.db', '.sbe');

      expect(backupDeviceTagFromFilename(name), deviceTag(thisDevice));
    });

    test('a legacy name carries no tag', () {
      expect(
        backupDeviceTagFromFilename('submersion_backup_2026-08-31_121314.db'),
        isNull,
      );
    });

    test('an unrelated file carries no tag', () {
      expect(backupDeviceTagFromFilename('holiday_photos.db'), isNull);
      expect(backupDeviceTagFromFilename('.hidden.db.tmp'), isNull);
    });

    test('a sidecar borrowing a backup name carries no tag', () {
      // The part 2 scan sees the whole directory, not just what this app
      // wrote. An interrupted write or a sync client's decoration keeps the
      // real backup's name and adds to it, so a parse that stopped at the
      // first dot would read our own tag back out of a file we never wrote.
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      expect(backupDeviceTagFromFilename('$name.tmp'), isNull);
      expect(backupDeviceTagFromFilename('$name.part'), isNull);
      expect(
        backupDeviceTagFromFilename(
          name.replaceAll('.db', ' (conflicted copy).db'),
        ),
        isNull,
      );
      expect(
        backupDeviceTagFromFilename(name.replaceAll('.db', '.txt')),
        isNull,
      );
    });

    test('the extension set covers the encrypted artifact', () {
      // The encrypted name is derived as basenameWithoutExtension + this
      // constant, so a change there would silently make every encrypted
      // backup unattributable.
      expect(backupFileExtensions, contains(BackupCrypto.fileExtension));
      expect(backupFileExtensions, contains('.db'));
    });
  });

  group('classifyBackupFile', () {
    test('a backup this device wrote is claimed', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      expect(
        classifyBackupFile(filename: name, thisDeviceId: thisDevice),
        BackupOwnership.thisDevice,
      );
    });

    test('a backup another device wrote is never claimed', () {
      // The hazard this whole module exists for. The app tells users to point
      // the backup folder at Dropbox or Google Drive, so another device's
      // backups sit in the same directory and are absent from this device's
      // history. Deleting them would destroy the only copy they have.
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: otherDevice,
      );

      expect(
        classifyBackupFile(filename: name, thisDeviceId: thisDevice),
        BackupOwnership.otherDevice,
      );
    });

    test('a legacy backup is unattributed rather than claimed', () {
      // Attribution fixes the future, not the past: a file written before this
      // shipped can never be traced, so it must never be offered for deletion.
      expect(
        classifyBackupFile(
          filename: 'submersion_backup_2026-08-31_121314.db',
          thisDeviceId: thisDevice,
        ),
        BackupOwnership.unattributed,
      );
    });

    test('a sidecar is never claimed, even carrying our own tag', () {
      // The safety-relevant half of the parse hardening: this file's name
      // contains this device's tag, and it still must not be offered for
      // deletion, because it is not one of our backups.
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      expect(
        classifyBackupFile(filename: '$name.tmp', thisDeviceId: thisDevice),
        BackupOwnership.unattributed,
      );
    });

    test('nothing is claimed when this device has no id yet', () {
      final name = buildBackupFilename(
        timestamp: '2026-08-31_121314',
        deviceId: thisDevice,
      );

      expect(
        classifyBackupFile(filename: name, thisDeviceId: ''),
        BackupOwnership.unattributed,
      );
    });
  });
}
