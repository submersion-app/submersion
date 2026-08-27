import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

ExtractedFile _ef(String path, {DateTime? takenAt}) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(takenAt: takenAt, mimeType: 'image/jpeg'),
);

void main() {
  test('ExtractedFile equality is value-based', () {
    final a = _ef('/x.jpg');
    final b = _ef('/x.jpg');
    expect(a, b);
  });

  test('MatchedSelection.empty has no files and no dives', () {
    final s = MatchedSelection.empty();
    expect(s.matched, isEmpty);
    expect(s.unmatched, isEmpty);
    expect(s.totalFiles, 0);
    expect(s.diveCount, 0);
  });

  test('MatchedSelection counts matched + unmatched', () {
    final s = MatchedSelection(
      matched: {
        'dive-1': [_ef('/a.jpg'), _ef('/b.jpg')],
      },
      unmatched: [_ef('/c.jpg')],
    );
    expect(s.totalFiles, 3);
    expect(s.diveCount, 1);
    expect(s.matched['dive-1']!.length, 2);
    expect(s.unmatched.length, 1);
  });

  test('MatchedSelection equality is value-based', () {
    final s1 = MatchedSelection(
      matched: {
        'd1': [_ef('/a.jpg')],
      },
      unmatched: const [],
    );
    final s2 = MatchedSelection(
      matched: {
        'd1': [_ef('/a.jpg')],
      },
      unmatched: const [],
    );
    expect(s1, s2);
  });
}
