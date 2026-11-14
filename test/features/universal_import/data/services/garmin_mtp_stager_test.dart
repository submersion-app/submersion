// Copies a Garmin watch's activity FITs off a fake MTP source into a
// staging folder, which the folder import then reads like a mounted drive
// (issue #4223).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_stager.dart';

import 'fake_garmin_mtp_source.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('garmin_mtp_stager_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Uint8List bytes(int seed) => Uint8List.fromList([seed, seed + 1, seed + 2]);

  GarminMtpStager stagerFor(FakeGarminMtpSource source) =>
      GarminMtpStager(source: source, tempRoot: () async => tmp);

  test('copies only .fit files, in name order, into a new folder', () async {
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {'b.FIT': bytes(2), 'a.fit': bytes(1), 'notes.txt': bytes(9)},
      },
    );

    final staging = await stagerFor(source).stage(watch.id);

    expect(p.isWithin(tmp.path, staging.dirPath), isTrue);
    final names = Directory(
      staging.dirPath,
    ).listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(names, ['a.fit', 'b.FIT']);
    expect(
      await File(p.join(staging.dirPath, 'a.fit')).readAsBytes(),
      bytes(1),
    );
    expect(source.readObjectIds, ['${watch.id}/a.fit', '${watch.id}/b.FIT']);
    expect(staging.copiedCount, 2);
    expect(staging.failedCount, 0);
  });

  group('after a marker (issue #4223)', () {
    const marker = GarminActivityMarker(name: '2026-11-01-10-00-00.fit');

    test('copies only the activities after it', () async {
      final watch = fakeGarminWatch();
      final source = FakeGarminMtpSource(
        devices: [watch],
        filesByDevice: {
          watch.id: {
            '2026-10-01-08-00-00.fit': bytes(1),
            '2026-11-01-10-00-00.fit': bytes(2),
            '2026-11-02-09-30-00.fit': bytes(3),
          },
        },
      );

      final staging = await stagerFor(source).stage(watch.id, after: marker);

      expect(source.readObjectIds, ['${watch.id}/2026-11-02-09-30-00.fit']);
      expect(staging.copiedCount, 1);
      expect(staging.skippedCount, 2);
      expect(
        staging.newest,
        const GarminActivityMarker(name: '2026-11-02-09-30-00.fit'),
      );
    });

    test(
      'copies nothing when nothing is newer, but still names the newest',
      () async {
        final watch = fakeGarminWatch();
        final source = FakeGarminMtpSource(
          devices: [watch],
          filesByDevice: {
            watch.id: {'2026-10-01-08-00-00.fit': bytes(1)},
          },
        );

        final staging = await stagerFor(source).stage(watch.id, after: marker);

        expect(source.readObjectIds, isEmpty);
        expect(staging.copiedCount, 0);
        expect(staging.skippedCount, 1);
        expect(
          staging.newest,
          const GarminActivityMarker(name: '2026-10-01-08-00-00.fit'),
        );
      },
    );
  });

  test('reports progress after each file, starting from zero', () async {
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {'1.fit': bytes(1), '2.fit': bytes(2), '3.fit': bytes(3)},
      },
    );
    final progress = <(int, int)>[];

    await stagerFor(
      source,
    ).stage(watch.id, onProgress: (done, total) => progress.add((done, total)));

    expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
  });

  test('skips a file that fails to read and keeps going', () async {
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {'1.fit': bytes(1), '2.fit': bytes(2)},
      },
      failingFiles: {'1.fit'},
    );

    final staging = await stagerFor(source).stage(watch.id);

    expect(File(p.join(staging.dirPath, '1.fit')).existsSync(), isFalse);
    expect(File(p.join(staging.dirPath, '2.fit')).existsSync(), isTrue);
    expect(staging.copiedCount, 1);
    expect(staging.failedCount, 1);
  });

  test('rethrows when no file could be read, and deletes its folder', () async {
    // A watch unplugged as the copy starts fails every read. That is a
    // watch that could not be read, not a watch with nothing on it.
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {'1.fit': bytes(1), '2.fit': bytes(2)},
      },
      failingFiles: {'1.fit', '2.fit'},
    );

    await expectLater(
      stagerFor(source).stage(watch.id),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'ioError'),
      ),
    );
    expect(tmp.listSync(), isEmpty);
  });

  test('keeps a device-supplied name inside the staging folder', () async {
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      filesByDevice: {
        watch.id: {p.join('..', 'escape.fit'): bytes(1)},
      },
    );

    final staging = await stagerFor(source).stage(watch.id);

    expect(File(p.join(staging.dirPath, 'escape.fit')).existsSync(), isTrue);
    expect(File(p.join(tmp.path, 'escape.fit')).existsSync(), isFalse);
  });

  test('deletes its folder and rethrows when listing fails', () async {
    final watch = fakeGarminWatch();
    final source = FakeGarminMtpSource(
      devices: [watch],
      listFilesError: PlatformException(code: 'busy'),
    );

    await expectLater(
      stagerFor(source).stage(watch.id),
      throwsA(isA<PlatformException>()),
    );
    expect(tmp.listSync(), isEmpty);
  });
}
