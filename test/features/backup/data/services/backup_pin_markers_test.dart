import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';

void main() {
  const stem = 'submersion_backup_2026-10-01_090000__d0123456789abcdef';

  group('pinMarkerName', () {
    test('drops the extension and adds the pinning device tag', () {
      final tag = deviceTag('dev-B');
      expect(
        pinMarkerName(backupFilename: '$stem.sbe', pinningDeviceId: 'dev-B'),
        '${stem}__p$tag.pin',
      );
    });

    test('.db and .sbe copies of one backup share a marker', () {
      expect(
        pinMarkerName(backupFilename: '$stem.db', pinningDeviceId: 'dev-B'),
        pinMarkerName(backupFilename: '$stem.sbe', pinningDeviceId: 'dev-B'),
      );
    });

    test('two devices pinning one backup get different markers', () {
      expect(
        pinMarkerName(backupFilename: '$stem.db', pinningDeviceId: 'dev-A'),
        isNot(
          pinMarkerName(backupFilename: '$stem.db', pinningDeviceId: 'dev-B'),
        ),
      );
    });
  });

  group('parsePinMarker', () {
    test('round-trips the backup stem and the device tag', () {
      final name = pinMarkerName(
        backupFilename: '$stem.db',
        pinningDeviceId: 'dev-B',
      );
      final marker = parsePinMarker(name);
      expect(marker?.backupStem, stem);
      expect(marker?.deviceTag, deviceTag('dev-B'));
    });

    test('reads an unattributed backup name', () {
      final name = pinMarkerName(
        backupFilename: 'submersion_backup_2024-01-01_120000.db',
        pinningDeviceId: 'dev-B',
      );
      expect(
        parsePinMarker(name)?.backupStem,
        'submersion_backup_2024-01-01_120000',
      );
    });

    test('rejects anything that is not a marker', () {
      for (final name in [
        '$stem.db',
        '$stem.sbe',
        'submersion_backup_X__pZZ.pin',
        'submersion_backup_X__p0123456789ABCDEF.pin',
        'other__p0123456789abcdef.pin',
        'submersion_backup_X__p0123456789abcdef.pin.tmp',
        'submersion_backup___p0123456789abcdef.pin',
      ]) {
        expect(parsePinMarker(name), isNull, reason: name);
      }
    });
  });

  test('backupStem strips .db and .sbe', () {
    expect(backupStem('$stem.db'), stem);
    expect(backupStem('$stem.sbe'), stem);
  });
}
