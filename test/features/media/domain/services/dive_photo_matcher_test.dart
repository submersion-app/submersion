import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

ExtractedFile _ef(String path, DateTime? takenAt) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
);

DiveBounds _dive(String id, DateTime start, Duration runtime) =>
    DiveBounds(diveId: id, entryTime: start, exitTime: start.add(runtime));

void main() {
  final matcher = DivePhotoMatcher();

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
}
