import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/storage/scratch_sweep.dart';

void main() {
  group('shouldSweepScratch', () {
    final now = DateTime.utc(2026, 8, 31, 12);

    test('a device that has never swept is due', () {
      expect(shouldSweepScratch(lastSweptAt: null, now: now), isTrue);
    });

    test('a sweep within the last day is not due', () {
      expect(
        shouldSweepScratch(
          lastSweptAt: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a sweep a day old is due', () {
      expect(
        shouldSweepScratch(
          lastSweptAt: now.subtract(const Duration(days: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a stamp far in the future is due rather than suppressing', () {
      // A broken clock must not stop the sweep until real time catches up.
      // Same defence as shouldAutoScan and shouldAutoVerify.
      expect(
        shouldSweepScratch(
          lastSweptAt: now.add(const Duration(days: 400)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a slightly future stamp still counts as a recent sweep', () {
      expect(
        shouldSweepScratch(
          lastSweptAt: now.add(const Duration(hours: 2)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('StorageScratchSweep', () {
    late Directory root;
    late Directory temp;
    late Directory support;
    final now = DateTime.utc(2026, 8, 31, 12);

    setUp(() async {
      root = await Directory.systemTemp.createTemp('scratch_sweep_test');
      temp = Directory(p.join(root.path, 'temp'));
      support = Directory(p.join(root.path, 'support'));
      await temp.create(recursive: true);
      await support.create(recursive: true);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    StorageScratchSweep build() => StorageScratchSweep(
      temporaryDirectory: () async => temp,
      supportDirectory: () async => support,
    );

    Future<File> write(String absolute, int bytes, Duration age) async {
      final file = File(absolute);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(bytes, 0));
      await file.setLastModified(now.subtract(age));
      return file;
    }

    String picked(String name) => p.join(temp.path, 'picked', name);
    String staging(String name) =>
        p.join(support.path, 'Submersion', 'media_cache', 'staging', name);
    String transcode(String name) =>
        p.join(support.path, 'Submersion', 'media_cache', 'transcode', name);
    String videoThumb(String name) =>
        p.join(support.path, 'Submersion', 'video_thumbnails', name);
    String pdfThumb(String name) =>
        p.join(support.path, 'Submersion', 'pdf_thumbnails', name);

    test('removes stale picked imports and keeps a fresh one', () async {
      final stale = await write(
        picked('0/dives.zip'),
        500,
        const Duration(days: 2),
      );
      final fresh = await write(
        picked('1/photos.zip'),
        400,
        const Duration(hours: 1),
      );

      final report = await build().run(now: now);

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'an import may be in flight');
      expect(report.filesDeleted, 1);
      expect(report.bytesReclaimed, 500);
    });

    test('removes stale staging files and keeps a fresh one', () async {
      final stale = await write(
        staging('stage_1'),
        70,
        const Duration(days: 3),
      );
      final fresh = await write(
        staging('stage_2'),
        30,
        const Duration(minutes: 5),
      );

      await build().run(now: now);

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'a put() may be mid-flight');
    });

    test('keeps transcode artifacts for a week before reclaiming', () async {
      final stale = await write(
        transcode('a_high.mp4'),
        900,
        const Duration(days: 8),
      );
      final recent = await write(
        transcode('b_high.mp4'),
        900,
        const Duration(days: 3),
      );

      await build().run(now: now);

      expect(stale.existsSync(), isFalse);
      expect(
        recent.existsSync(),
        isTrue,
        reason: 'an upload retrying over days must keep its rendition',
      );
    });

    test('reclaims thumbnails only after a month', () async {
      final staleVideo = await write(
        videoThumb('aa.img'),
        12,
        const Duration(days: 40),
      );
      final stalePdf = await write(
        pdfThumb('bb.jpg'),
        34,
        const Duration(days: 40),
      );
      final freshVideo = await write(
        videoThumb('cc.img'),
        12,
        const Duration(days: 5),
      );

      await build().run(now: now);

      expect(staleVideo.existsSync(), isFalse);
      expect(stalePdf.existsSync(), isFalse);
      expect(freshVideo.existsSync(), isTrue);
    });

    test('prunes directories it emptied, but not ones still in use', () async {
      await write(picked('0/dives.zip'), 10, const Duration(days: 2));
      await write(picked('1/keep.zip'), 10, const Duration(hours: 1));

      await build().run(now: now);

      expect(Directory(p.join(temp.path, 'picked', '0')).existsSync(), isFalse);
      expect(Directory(p.join(temp.path, 'picked', '1')).existsSync(), isTrue);
    });

    test('leaves an empty directory it did not empty alone', () async {
      // A pick materializing right now creates its subdirectory before it
      // opens the destination file, so an empty directory is not evidence of
      // abandoned scratch. Only what this pass emptied is a prune candidate.
      final inFlight = Directory(p.join(temp.path, 'picked', 'in_flight'));
      await inFlight.create(recursive: true);
      await write(picked('0/dives.zip'), 10, const Duration(days: 2));

      await build().run(now: now);

      expect(
        inFlight.existsSync(),
        isTrue,
        reason: 'a writer may be about to create its file in there',
      );
      expect(Directory(p.join(temp.path, 'picked', '0')).existsSync(), isFalse);
    });

    test('prunes the whole chain a nested file left empty', () async {
      await write(picked('0/inner/dives.zip'), 10, const Duration(days: 2));

      await build().run(now: now);

      expect(Directory(p.join(temp.path, 'picked', '0')).existsSync(), isFalse);
    });

    test('never touches anything outside the directories it owns', () async {
      // The temp root holds files other plugins wrote, and share files whose
      // names this app cannot distinguish from theirs. Documents holds the
      // database and the user's exports. None of it is ours to delete.
      final looseTemp = await write(
        p.join(temp.path, 'someone_elses.tmp'),
        99,
        const Duration(days: 400),
      );
      final otherPlugin = await write(
        p.join(temp.path, 'libCachedImageData', 'blob.bin'),
        99,
        const Duration(days: 400),
      );
      final appData = await write(
        p.join(support.path, 'Submersion', 'submersion_local.db'),
        99,
        const Duration(days: 400),
      );
      final cachedOriginal = await write(
        p.join(
          support.path,
          'Submersion',
          'media_cache',
          'originals',
          'aa',
          'x',
        ),
        99,
        const Duration(days: 400),
      );

      final report = await build().run(now: now);

      expect(looseTemp.existsSync(), isTrue);
      expect(otherPlugin.existsSync(), isTrue);
      expect(appData.existsSync(), isTrue);
      expect(
        cachedOriginal.existsSync(),
        isTrue,
        reason: 'the indexed pools are governed by their own LRU, not by age',
      );
      expect(report.filesDeleted, 0);
    });

    test('a missing directory is a no-op rather than a failure', () async {
      final report = await build().run(now: now);

      expect(report.filesDeleted, 0);
      expect(report.bytesReclaimed, 0);
    });

    test('reports what it reclaimed across every target', () async {
      await write(picked('0/a.zip'), 100, const Duration(days: 2));
      await write(staging('stage_1'), 200, const Duration(days: 2));
      await write(transcode('c_high.mp4'), 300, const Duration(days: 8));
      await write(videoThumb('dd.img'), 400, const Duration(days: 40));

      final report = await build().run(now: now);

      expect(report.filesDeleted, 4);
      expect(report.bytesReclaimed, 1000);
    });
  });
}
