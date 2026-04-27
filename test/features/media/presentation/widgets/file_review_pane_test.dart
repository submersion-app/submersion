import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: MediaSourceMetadata(
    takenAt: DateTime.utc(2024, 4, 1),
    mimeType: 'image/jpeg',
  ),
);

void main() {
  testWidgets('summary shows file/dive/unmatched counts', (tester) async {
    final state = FilesTabState.initial().copyWith(
      files: [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')],
      match: MatchedSelection(
        matched: {
          'd1': [_ef('/a.jpg'), _ef('/b.jpg')],
        },
        unmatched: [_ef('/c.jpg')],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FileReviewPane(state: state)),
      ),
    );
    expect(find.textContaining('3 photos'), findsOneWidget);
    expect(find.textContaining('1 dive'), findsOneWidget);
    expect(find.textContaining('1 unmatched'), findsOneWidget);
  });
}
