import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_origin.dart';

String _nameFrom(String deviceId) =>
    buildBackupFilename(timestamp: '2026-10-28_091400', deviceId: deviceId);

void main() {
  group('BackupOriginResolver (#3651)', () {
    final resolver = BackupOriginResolver(
      thisDeviceId: 'phone-id',
      peerDeviceNames: const {'laptop-id': "Eric's MacBook"},
    );

    test('a backup this device wrote is from this device', () {
      expect(
        resolver.originOf(_nameFrom('phone-id')),
        const BackupFromThisDevice(),
      );
    });

    test('a backup a named peer wrote carries that peer name', () {
      expect(
        resolver.originOf(_nameFrom('laptop-id')),
        const BackupFromNamedDevice("Eric's MacBook"),
      );
    });

    test('the encrypted variant is attributed like the plain one', () {
      final encrypted = _nameFrom('laptop-id').replaceAll('.db', '.sbe');
      expect(
        resolver.originOf(encrypted),
        const BackupFromNamedDevice("Eric's MacBook"),
      );
    });

    test('a backup from a device with no known name is another device', () {
      expect(
        resolver.originOf(_nameFrom('tablet-id')),
        const BackupFromAnotherDevice(),
      );
    });

    test('a backup made before attribution has no origin', () {
      expect(
        resolver.originOf('submersion_backup_2026-09-02_181500.db'),
        isNull,
      );
    });

    test('a pre-migration copy, which carries no tag, has no origin', () {
      expect(
        resolver.originOf('pre_migration_v63_to_v64_2026-04-12.db'),
        isNull,
      );
    });

    test('this device wins over a peer entry with the same id', () {
      final both = BackupOriginResolver(
        thisDeviceId: 'phone-id',
        peerDeviceNames: const {'phone-id': 'Stale name'},
      );
      expect(
        both.originOf(_nameFrom('phone-id')),
        const BackupFromThisDevice(),
      );
    });

    test('an empty peer name does not label the device', () {
      final blank = BackupOriginResolver(
        thisDeviceId: 'phone-id',
        peerDeviceNames: const {'laptop-id': ''},
      );
      expect(
        blank.originOf(_nameFrom('laptop-id')),
        const BackupFromAnotherDevice(),
      );
    });

    group('when this device id is unknown', () {
      for (final id in [null, '']) {
        final unknown = BackupOriginResolver(
          thisDeviceId: id,
          peerDeviceNames: const {'laptop-id': "Eric's MacBook"},
        );

        test('a named peer is still named (id: ${id ?? 'null'})', () {
          expect(
            unknown.originOf(_nameFrom('laptop-id')),
            const BackupFromNamedDevice("Eric's MacBook"),
          );
        });

        test('an unnamed tag may be ours, so it has no origin '
            '(id: ${id ?? 'null'})', () {
          expect(unknown.originOf(_nameFrom('phone-id')), isNull);
        });
      }
    });
  });
}
