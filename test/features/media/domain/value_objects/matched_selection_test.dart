import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

void main() {
  test('diagnostics default to empty', () {
    final selection = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
    );
    expect(selection.diagnostics, isEmpty);
  });

  test('copyWith preserves diagnostics when only buckets change', () {
    const diagnostic = UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp);
    final selection = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {'/a.jpg': diagnostic},
    );

    final moved = selection.copyWith(
      matched: {
        'dive-1': [_ef('/a.jpg')],
      },
      unmatched: const [],
    );

    expect(moved.diagnostics, {'/a.jpg': diagnostic});
    expect(moved.unmatched, isEmpty);
    expect(moved.matched['dive-1'], isNotNull);
  });

  test('diagnostics participate in equality', () {
    final a = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {
        '/a.jpg': UnmatchedDiagnostic(reason: UnmatchedReason.noTimestamp),
      },
    );
    final b = MatchedSelection(
      matched: const {},
      unmatched: [_ef('/a.jpg')],
      diagnostics: const {
        '/a.jpg': UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(hours: 5),
        ),
      },
    );

    expect(a, isNot(b));
  });
}
