// Verifies Garmin USB detection against a temporary directory tree that
// mimics one or more mounted volumes: a device is recognised by a non-empty
// GARMIN/Activity folder, regardless of the volume's name.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';

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

  GarminDeviceDetector detectorFor(List<String> volumeRoots) {
    return GarminDeviceDetector(
      volumeRoots: () => [for (final r in volumeRoots) Directory(r)],
    );
  }

  test('detects a volume with a non-empty GARMIN/Activity folder', () async {
    final vol = await makeVolume(
      'GARMIN',
      fitNames: ['1.fit', '2.fit'],
      otherNames: ['notes.txt'],
    );

    final devices = await detectorFor([vol]).detect();

    expect(devices, hasLength(1));
    expect(devices.single.volumeName, 'GARMIN');
    expect(devices.single.fitFileCount, 2);
    expect(devices.single.activityDirPath, p.join(vol, 'GARMIN', 'Activity'));
  });

  test('recognises the device regardless of the volume name', () async {
    final vol = await makeVolume('MY_WATCH', fitNames: ['a.fit']);

    final devices = await detectorFor([vol]).detect();

    expect(devices, hasLength(1));
    expect(devices.single.volumeName, 'MY_WATCH');
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

    expect(devices.map((d) => d.volumeName), containsAll(['A', 'B']));
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
}
