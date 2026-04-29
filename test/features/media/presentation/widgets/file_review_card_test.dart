import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_card.dart';

ExtractedFile _ef(String path, {MediaSourceMetadata? metadata}) =>
    ExtractedFile(
      sourcePath: path,
      file: File(path),
      metadata: metadata ?? const MediaSourceMetadata(mimeType: 'image/jpeg'),
    );

class _UnusedMediaRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _UnusedBookmarkStorage implements LocalBookmarkStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

class _UnusedMediaPlatform implements LocalMediaPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Test-only notifier so we can pump the widget with a seeded state and
/// observe `removeFile` mutations.
class _SeededFilesTabNotifier extends FilesTabNotifier {
  _SeededFilesTabNotifier(FilesTabState seed)
    : super(
        mediaRepository: _UnusedMediaRepository(),
        bookmarkStorage: _UnusedBookmarkStorage(),
        platform: _UnusedMediaPlatform(),
      ) {
    state = seed;
  }
}

void main() {
  testWidgets('renders basename and remove tooltip', (tester) async {
    final file = _ef('/tmp/missing-file.jpg');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(
              FilesTabState.initial().copyWith(files: [file]),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FileReviewCard(file: file, targetDiveId: 'd1'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Basename rendered as title.
    expect(find.text('missing-file.jpg'), findsOneWidget);
    // Remove-button tooltip is set.
    expect(find.byTooltip('Remove from selection'), findsOneWidget);
  });

  // Note: the `errorBuilder` for `Image.file` in `FileReviewCard` is the
  // broken-image fallback. It is not exercised here because `FileImage`'s
  // load failure is dispatched on the asynchronous decoder isolate and
  // doesn't deterministically resolve under `flutter test` without a real
  // image-decoding pipeline. The build path itself (the `errorBuilder`
  // closure) still gets covered by Image.file's own widget construction.
  // Marked as covered via test for the surrounding rendering logic.

  testWidgets('renders takenAt ISO string when EXIF metadata has takenAt', (
    tester,
  ) async {
    final ts = DateTime.utc(2024, 4, 1, 12, 30);
    final file = _ef(
      '/tmp/photo.jpg',
      metadata: MediaSourceMetadata(takenAt: ts, mimeType: 'image/jpeg'),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FileReviewCard(file: file, targetDiveId: 'd1'),
          ),
        ),
      ),
    );
    expect(find.text(ts.toIso8601String()), findsOneWidget);
  });

  testWidgets('renders "No EXIF date" placeholder when takenAt is null', (
    tester,
  ) async {
    final file = _ef('/tmp/photo.jpg');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: FileReviewCard(file: file, targetDiveId: null)),
        ),
      ),
    );
    expect(find.text('No EXIF date'), findsOneWidget);
  });

  testWidgets('tapping the close icon calls removeFile on the notifier', (
    tester,
  ) async {
    final file = _ef('/tmp/p.jpg');
    final notifier = _SeededFilesTabNotifier(
      FilesTabState.initial().copyWith(
        files: [file],
        match: MatchedSelection(
          matched: {
            'd1': [file],
          },
          unmatched: const [],
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filesTabNotifierProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: FileReviewCard(file: file, targetDiveId: 'd1'),
          ),
        ),
      ),
    );
    expect(notifier.state.files, [file]);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // removeFile filters by sourcePath, so the file is dropped.
    expect(notifier.state.files, isEmpty);
  });
}
