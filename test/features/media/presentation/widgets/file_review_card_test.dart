import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_card.dart';

import '../../../../helpers/test_app.dart';

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

/// Pumps one card inside a localized app with a seeded notifier.
///
/// The card reads `context.l10n`, so a bare MaterialApp without delegates
/// throws a null check. The locale is pinned to English because these tests
/// assert on English labels.
Future<void> _pumpCard(
  WidgetTester tester, {
  required ExtractedFile file,
  String? targetDiveId,
  String? assignableDiveId,
  UnmatchedDiagnostic? diagnostic,
  Duration captureTimeOffset = Duration.zero,
  FilesTabNotifier? notifier,
}) async {
  final seeded =
      notifier ??
      _SeededFilesTabNotifier(FilesTabState.initial().copyWith(files: [file]));
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [filesTabNotifierProvider.overrideWith((ref) => seeded)],
      child: FileReviewCard(
        file: file,
        targetDiveId: targetDiveId,
        assignableDiveId: assignableDiveId,
        diagnostic: diagnostic,
        captureTimeOffset: captureTimeOffset,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders basename and remove tooltip', (tester) async {
    await _pumpCard(
      tester,
      file: _ef('/tmp/missing-file.jpg'),
      targetDiveId: 'd1',
    );

    expect(find.text('missing-file.jpg'), findsOneWidget);
    expect(find.byTooltip('Remove from selection'), findsOneWidget);
  });

  testWidgets('renders a video icon (not Image.file) for video MIME', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      file: _ef(
        '/tmp/clip.mp4',
        metadata: const MediaSourceMetadata(mimeType: 'video/mp4'),
      ),
      targetDiveId: 'd1',
    );

    // Videos can't be decoded as images; show an explicit video icon rather
    // than Image.file's broken-image fallback (which reads as an error).
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  // Note: the `errorBuilder` for `Image.file` in `FileReviewCard` is the
  // broken-image fallback. It is not exercised here because `FileImage`'s
  // load failure is dispatched on the asynchronous decoder isolate and
  // doesn't deterministically resolve under `flutter test` without a real
  // image-decoding pipeline.

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
    await _pumpCard(tester, file: file, targetDiveId: 'd1', notifier: notifier);
    expect(notifier.state.files, [file]);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // removeFile filters by sourcePath, so the file is dropped.
    expect(notifier.state.files, isEmpty);
  });

  group('capture time provenance', () {
    testWidgets('labels a native EXIF capture time', (tester) async {
      await _pumpCard(
        tester,
        file: _ef(
          '/tmp/photo.jpg',
          metadata: MediaSourceMetadata(
            takenAt: DateTime.utc(2025, 12, 27, 11, 47),
            takenAtSource: TakenAtSource.nativeExif,
            mimeType: 'image/jpeg',
          ),
        ),
        targetDiveId: 'd1',
      );

      expect(find.textContaining('2025-12-27 11:47'), findsOneWidget);
      expect(find.textContaining('from EXIF'), findsOneWidget);
    });

    testWidgets('labels a container-metadata capture time', (tester) async {
      await _pumpCard(
        tester,
        file: _ef(
          '/tmp/clip.mp4',
          metadata: MediaSourceMetadata(
            takenAt: DateTime.utc(2025, 12, 27, 11, 47),
            takenAtSource: TakenAtSource.containerMetadata,
            mimeType: 'video/mp4',
          ),
        ),
        targetDiveId: 'd1',
      );

      expect(find.textContaining('from file metadata'), findsOneWidget);
    });

    testWidgets('flags a time that is only the file date', (tester) async {
      await _pumpCard(
        tester,
        file: _ef(
          '/tmp/photo.jpg',
          metadata: MediaSourceMetadata(
            takenAt: DateTime.utc(2026, 4, 2, 9),
            takenAtSource: TakenAtSource.fileModifiedTime,
            mimeType: 'image/jpeg',
          ),
        ),
        targetDiveId: 'd1',
      );

      expect(find.textContaining('from file date'), findsOneWidget);
    });

    testWidgets('says so when nothing dated the file', (tester) async {
      await _pumpCard(tester, file: _ef('/tmp/photo.jpg'), targetDiveId: 'd1');

      expect(find.text('no date found'), findsOneWidget);
    });

    testWidgets('shows the shifted time alongside the original', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef(
          '/tmp/photo.jpg',
          metadata: MediaSourceMetadata(
            takenAt: DateTime.utc(2025, 12, 27, 16, 47),
            takenAtSource: TakenAtSource.nativeExif,
            mimeType: 'image/jpeg',
          ),
        ),
        targetDiveId: 'd1',
        captureTimeOffset: const Duration(hours: -5),
      );

      // The corrected time leads; the value actually read from the file
      // follows, so the diver can see what was changed on their behalf.
      expect(find.textContaining('2025-12-27 11:47'), findsOneWidget);
      expect(find.textContaining('was 2025-12-27 16:47'), findsOneWidget);
    });
  });

  group('unmatched reason', () {
    testWidgets('explains a file with no capture time', (tester) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.noTimestamp,
        ),
      );

      expect(find.text('No capture time could be read'), findsOneWidget);
    });

    testWidgets('reports how far a late file missed the nearest dive', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(hours: 3, minutes: 38),
        ),
      );

      expect(find.text('3h 38m after the nearest dive'), findsOneWidget);
    });

    testWidgets('reports how far an early file missed the nearest dive', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
          nearestDiveId: 'dive-1',
          gapToNearest: Duration(hours: -1),
        ),
      );

      expect(find.text('1h 00m before the nearest dive'), findsOneWidget);
    });

    testWidgets('says so when there were no dives to match against', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        file: _ef('/tmp/photo.jpg'),
        diagnostic: const UnmatchedDiagnostic(
          reason: UnmatchedReason.outsideAllWindows,
        ),
      );

      expect(find.text('No dives to match against'), findsOneWidget);
    });

    testWidgets('a matched card shows no reason line', (tester) async {
      await _pumpCard(tester, file: _ef('/tmp/photo.jpg'), targetDiveId: 'd1');

      expect(find.textContaining('nearest dive'), findsNothing);
      expect(find.text('No capture time could be read'), findsNothing);
    });
  });

  group('routes into a dive', () {
    testWidgets('offers a dive chooser when there is no assignable dive', (
      tester,
    ) async {
      // The library-import case: commit() only persists files sitting in a
      // dive group, so without this the file has no route into the database.
      await _pumpCard(tester, file: _ef('/a.jpg'));

      expect(find.byTooltip('Choose a dive'), findsOneWidget);
      expect(find.byTooltip('Add to this dive'), findsNothing);
    });

    testWidgets('keeps the direct add action when a dive is assignable', (
      tester,
    ) async {
      await _pumpCard(tester, file: _ef('/a.jpg'), assignableDiveId: 'dive-1');

      expect(find.byTooltip('Add to this dive'), findsOneWidget);
      expect(find.byTooltip('Choose a dive'), findsNothing);
    });

    testWidgets('a card already in a dive group offers neither', (
      tester,
    ) async {
      await _pumpCard(tester, file: _ef('/a.jpg'), targetDiveId: 'dive-1');

      expect(find.byTooltip('Add to this dive'), findsNothing);
      expect(find.byTooltip('Choose a dive'), findsNothing);
    });

    testWidgets('the direct add routes the file to the picker dive', (
      tester,
    ) async {
      final file = _ef('/a.jpg');
      final notifier = _SeededFilesTabNotifier(
        FilesTabState.initial().copyWith(
          files: [file],
          match: MatchedSelection(matched: const {}, unmatched: [file]),
        ),
      );
      await _pumpCard(
        tester,
        file: file,
        assignableDiveId: 'dive-1',
        notifier: notifier,
      );

      await tester.tap(find.byTooltip('Add to this dive'));
      await tester.pump();

      expect(notifier.state.match.matched['dive-1'], [file]);
      expect(notifier.state.match.unmatched, isEmpty);
    });
  });
}
