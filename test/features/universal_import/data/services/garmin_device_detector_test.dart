// Verifies Garmin USB detection against a temporary directory tree that
// mimics one or more mounted volumes: a device is recognised by a non-empty
// GARMIN/Activity folder, regardless of the volume's name. A fake MTP source
// stands in for watches that connect over MTP instead (issue #4223).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';

import 'fake_garmin_mtp_source.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('garmin_detect_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  /// Create `<tmp>/<volume>/GARMIN/Activity` and drop [fitNames] into it (plus
  /// any [otherNames] non-FIT files). Returns the volume root path.
  Future<String> makeVolume(
    String volume, {
    List<String> fitNames = const [],
    List<String> otherNames = const [],
  }) async {
    final activity = Directory(p.join(tmp.path, volume, 'GARMIN', 'Activity'));
    await activity.create(recursive: true);
    for (final name in fitNames) {
      await File(p.join(activity.path, name)).writeAsBytes([0, 1, 2, 3]);
    }
    for (final name in otherNames) {
      await File(p.join(activity.path, name)).writeAsString('x');
    }
    return p.join(tmp.path, volume);
  }

  GarminDeviceDetector detectorFor(
    List<String> volumeRoots, {
    FakeGarminMtpSource? mtpSource,
  }) {
    return GarminDeviceDetector(
      volumeRoots: () => [for (final r in volumeRoots) Directory(r)],
      mtpSource: mtpSource,
    );
  }

  Iterable<GarminVolume> volumesIn(List<GarminDevice> devices) =>
      devices.whereType<GarminVolume>();

  test('detects a volume with a non-empty GARMIN/Activity folder', () async {
    final vol = await makeVolume(
      'GARMIN',
      fitNames: ['1.fit', '2.fit'],
      otherNames: ['notes.txt'],
    );

    final devices = await detectorFor([vol]).detect();

    expect(devices, hasLength(1));
    final volume = devices.single as GarminVolume;
    expect(volume.volumeName, 'GARMIN');
    expect(volume.displayName, 'GARMIN');
    expect(volume.fitFileCount, 2);
    expect(volume.activityDirPath, p.join(vol, 'GARMIN', 'Activity'));
  });

  group('serial number of a mounted volume (issue #4223)', () {
    test('comes from GARMIN/GarminDevice.xml', () async {
      final vol = await makeVolume('GARMIN', fitNames: ['1.fit']);
      await File(p.join(vol, 'GARMIN', 'GarminDevice.xml')).writeAsString(
        '<?xml version="1.0"?>\n'
        '<Device xmlns="http://www.garmin.com/xmlschemas/GarminDevice/v2">\n'
        '  <Model><PartNumber>006-B4518-00</PartNumber></Model>\n'
        '  <Id> 3456789012 </Id>\n'
        '</Device>\n',
      );

      final devices = await detectorFor([vol]).detect();

      expect(devices.single.serialNumber, '3456789012');
    });

    test('is null without the file', () async {
      final vol = await makeVolume('GARMIN', fitNames: ['1.fit']);

      final devices = await detectorFor([vol]).detect();

      expect(devices.single.serialNumber, isNull);
    });
  });

  test('recognises the device regardless of the volume name', () async {
    final vol = await makeVolume('MY_WATCH', fitNames: ['a.fit']);

    final devices = await detectorFor([vol]).detect();

    expect(devices, hasLength(1));
    expect((devices.single as GarminVolume).volumeName, 'MY_WATCH');
  });

  test('ignores a volume without a GARMIN/Activity folder', () async {
    final plainDir = Directory(p.join(tmp.path, 'USB_STICK'));
    await plainDir.create(recursive: true);
    await File(p.join(plainDir.path, 'photo.jpg')).writeAsString('x');

    final devices = await detectorFor([plainDir.path]).detect();

    expect(devices, isEmpty);
  });

  test('ignores a GARMIN/Activity folder with no FIT files', () async {
    final vol = await makeVolume('EMPTY', otherNames: ['README']);

    final devices = await detectorFor([vol]).detect();

    expect(devices, isEmpty);
  });

  test('returns every matching volume when several are mounted', () async {
    final a = await makeVolume('A', fitNames: ['1.fit']);
    final b = await makeVolume('B', fitNames: ['1.fit', '2.fit']);
    final plain = Directory(p.join(tmp.path, 'PLAIN'))
      ..createSync(recursive: true);

    final devices = await detectorFor([a, b, plain.path]).detect();

    expect(
      volumesIn(devices).map((d) => d.volumeName),
      containsAll(['A', 'B']),
    );
    expect(devices, hasLength(2));
  });

  test('listFitFiles returns only .fit paths, sorted', () async {
    final vol = await makeVolume(
      'GARMIN',
      fitNames: ['b.fit', 'a.fit'],
      otherNames: ['c.gpx'],
    );
    final activity = p.join(vol, 'GARMIN', 'Activity');

    final files = await detectorFor([vol]).listFitFiles(activity);

    expect(files.map(p.basename), ['a.fit', 'b.fit']);
  });

  test('listFitFiles is empty for a missing directory', () async {
    final files = await const GarminDeviceDetector().listFitFiles(
      p.join(tmp.path, 'does', 'not', 'exist'),
    );
    expect(files, isEmpty);
  });

  group('MTP watches', () {
    test('lists a Garmin watch the MTP source reports', () async {
      final watch = fakeGarminWatch(name: 'Descent G2', serial: '123');
      final devices = await detectorFor(
        const [],
        mtpSource: FakeGarminMtpSource(devices: [watch]),
      ).detect();

      expect(devices, hasLength(1));
      final mtp = devices.single as GarminMtpWatch;
      expect(mtp.deviceId, watch.id);
      expect(mtp.displayName, 'Descent G2');
      expect(mtp.serialNumber, '123');
    });

    test('reads the hex serial MTP reports as the decimal unit ID', () async {
      // Windows reports a Descent G2 unit ID 3339091223 as 0000c7067d17;
      // the FIT files and the saved computer hold the decimal form.
      Future<String?> serialOf(String reported) async {
        final devices = await detectorFor(
          const [],
          mtpSource: FakeGarminMtpSource(
            devices: [fakeGarminWatch(serial: reported)],
          ),
        ).detect();
        return devices.single.serialNumber;
      }

      expect(await serialOf('0000c7067d17'), '3339091223');
      expect(await serialOf('0000C7067D17'), '3339091223');
      // Anything else is passed on as it came.
      expect(await serialOf('3339091223'), '3339091223');
      expect(await serialOf('ABC-123'), 'ABC-123');
    });

    test('lists mounted volumes ahead of MTP watches', () async {
      final vol = await makeVolume('GARMIN', fitNames: ['1.fit']);
      final devices = await detectorFor([
        vol,
      ], mtpSource: FakeGarminMtpSource(devices: [fakeGarminWatch()])).detect();

      expect(devices.map((d) => d.runtimeType), [GarminVolume, GarminMtpWatch]);
    });

    test('a failing MTP source still lists the mounted volumes', () async {
      final vol = await makeVolume('GARMIN', fitNames: ['1.fit']);
      final devices = await detectorFor(
        [vol],
        mtpSource: FakeGarminMtpSource(
          listError: PlatformException(code: 'ioError'),
        ),
      ).detect();

      expect(devices, hasLength(1));
      expect(devices.single, isA<GarminVolume>());
    });

    test('without an MTP source only volumes are scanned', () async {
      final devices = await detectorFor(const []).detect();
      expect(devices, isEmpty);
    });
  });
}
