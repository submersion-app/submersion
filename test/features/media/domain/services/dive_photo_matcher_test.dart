import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';

ExtractedFile _ef(String path, DateTime? takenAt) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
);

DiveBounds _dive(String id, DateTime start, Duration runtime) =>
    DiveBounds(diveId: id, entryTime: start, exitTime: start.add(runtime));

void main() {
  const matcher = DivePhotoMatcher();

  test('routes file taken during dive window to that dive', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [_ef('/a.jpg', DateTime.utc(2024, 4, 1, 10, 15))];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched['d1'], isNotEmpty);
    expect(result.unmatched, isEmpty);
  });

  test('files within pre/post buffer route to the dive', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [
      _ef(
        '/pre.jpg',
        DateTime.utc(2024, 4, 1, 9, 45),
      ), // -15min, within preBuffer
      _ef(
        '/post.jpg',
        DateTime.utc(2024, 4, 1, 11, 30),
      ), // +15min after exit, within postBuffer
    ];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched['d1']!.length, 2);
    expect(result.unmatched, isEmpty);
  });

  test('no match when file is outside buffer window', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [
      _ef('/late.jpg', DateTime.utc(2024, 4, 1, 13, 0)), // way after
    ];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.matched, isEmpty);
    expect(result.unmatched.length, 1);
  });

  test('no match when file has no takenAt', () {
    final dive = _dive(
      'd1',
      DateTime.utc(2024, 4, 1, 10, 0),
      const Duration(minutes: 45),
    );
    final files = [_ef('/x.jpg', null)];
    final result = matcher.match(files: files, dives: [dive]);
    expect(result.unmatched.length, 1);
  });

  test('overlapping dives: closest entryTime wins', () {
    final earlier = _dive(
      'd-early',
      DateTime.utc(2024, 4, 1, 9, 30),
      const Duration(minutes: 60),
    );
    final later = _dive(
      'd-later',
      DateTime.utc(2024, 4, 1, 10, 5),
      const Duration(minutes: 60),
    );
    final files = [
      // 10:10 — both windows include it (earlier ends 10:30 + 60min = 11:30; later starts 10:05)
      // Closest entryTime: earlier=10:10-9:30=40min, later=10:10-10:05=5min → later wins.
      _ef('/x.jpg', DateTime.utc(2024, 4, 1, 10, 10)),
    ];
    final result = matcher.match(files: files, dives: [earlier, later]);
    expect(result.matched['d-later']!.length, 1);
    expect(result.matched.containsKey('d-early'), isFalse);
  });

  test('preBuffer is 30 minutes', () {
    expect(DivePhotoMatcher.preBuffer, const Duration(minutes: 30));
  });

  test('postBuffer is 60 minutes', () {
    expect(DivePhotoMatcher.postBuffer, const Duration(minutes: 60));
  });

  test('empty inputs produce empty result', () {
    final result = matcher.match(files: const [], dives: const []);
    expect(result.totalFiles, 0);
  });

  group('capture-time offset', () {
    final dive = DiveBounds(
      diveId: 'dive-1',
      entryTime: DateTime.utc(2025, 12, 27, 11, 26),
      exitTime: DateTime.utc(2025, 12, 27, 12, 9),
    );

    test('zero offset matches exactly as before', () {
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = matcher.match(files: [file], dives: [dive]);
      expect(result.matched['dive-1'], [file]);
    });

    test('a negative offset pulls a too-late file into the window', () {
      // Camera clock five hours fast: 16:47 recorded for an 11:47 photo.
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));

      final before = matcher.match(files: [file], dives: [dive]);
      expect(before.unmatched, [file]);

      final after = matcher.match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: -5),
      );
      expect(after.matched['dive-1'], [file]);
      expect(after.unmatched, isEmpty);
    });

    test('a positive offset pushes a too-early file into the window', () {
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 6, 47));
      final result = matcher.match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: 5),
      );
      expect(result.matched['dive-1'], [file]);
    });
  });

  group('unmatched diagnostics', () {
    final dive = DiveBounds(
      diveId: 'dive-1',
      entryTime: DateTime.utc(2025, 12, 27, 11, 26),
      exitTime: DateTime.utc(2025, 12, 27, 12, 9),
    );

    test('a file with no capture time reports noTimestamp', () {
      final result = matcher.match(files: [_ef('/a.jpg', null)], dives: [dive]);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.noTimestamp);
      expect(diagnostic.nearestDiveId, isNull);
      expect(diagnostic.gapToNearest, isNull);
    });

    test('a late file reports a positive gap past the post-buffer', () {
      // Window ends at exit 12:09 plus the 60-minute post-buffer = 13:09.
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
      final result = matcher.match(files: [file], dives: [dive]);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.outsideAllWindows);
      expect(diagnostic.nearestDiveId, 'dive-1');
      expect(diagnostic.gapToNearest, const Duration(hours: 3, minutes: 38));
    });

    test('an early file reports a negative gap before the pre-buffer', () {
      // Window starts at entry 11:26 minus the 30-minute pre-buffer = 10:56.
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 9, 56));
      final result = matcher.match(files: [file], dives: [dive]);

      expect(
        result.diagnostics['/a.jpg']!.gapToNearest,
        const Duration(hours: -1),
      );
    });

    test('the nearest dive wins among several', () {
      final later = DiveBounds(
        diveId: 'dive-2',
        entryTime: DateTime.utc(2025, 12, 27, 15, 0),
        exitTime: DateTime.utc(2025, 12, 27, 15, 40),
      );
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 18, 0));

      final result = matcher.match(files: [file], dives: [dive, later]);

      expect(result.diagnostics['/a.jpg']!.nearestDiveId, 'dive-2');
    });

    test('the gap is measured after the offset is applied', () {
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 16, 47));
      final result = matcher.match(
        files: [file],
        dives: [dive],
        offset: const Duration(hours: -1),
      );

      expect(
        result.diagnostics['/a.jpg']!.gapToNearest,
        const Duration(hours: 2, minutes: 38),
      );
    });

    test('matched files get no diagnostic entry', () {
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = matcher.match(files: [file], dives: [dive]);
      expect(result.diagnostics, isEmpty);
    });

    test('no dives at all still reports outsideAllWindows with no nearest', () {
      final file = _ef('/a.jpg', DateTime.utc(2025, 12, 27, 11, 47));
      final result = matcher.match(files: [file], dives: const []);

      final diagnostic = result.diagnostics['/a.jpg'];
      expect(diagnostic!.reason, UnmatchedReason.outsideAllWindows);
      expect(diagnostic.nearestDiveId, isNull);
    });
  });
}
