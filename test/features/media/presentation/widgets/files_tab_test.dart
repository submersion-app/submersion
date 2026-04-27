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
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

/// Hand-rolled fakes for tests that don't exercise the commit path.
/// Any unexpected call throws — these tests render the widget tree but
/// never click "Link N items", so no method on these fakes should be hit.
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

/// Test-only notifier that seeds an arbitrary initial [FilesTabState] so the
/// widget can be rendered in any branch without driving it through the
/// picker flow. Mirrors the seeding approach used in
/// `files_tab_providers_test.dart` (which uses a [ProviderContainer] and
/// public mutators), but expressed as a notifier override so widget tests
/// can pump the seeded state directly.
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
  testWidgets('renders Pick files action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.textContaining('Pick files'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty-state hint when no files picked', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.textContaining('Pick files or'), findsOneWidget);
  });

  testWidgets('renders LinearProgressIndicator while extracting', (
    tester,
  ) async {
    final seeded = FilesTabState.initial().copyWith(
      isExtracting: true,
      extractedCount: 2,
      totalToExtract: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('renders FileReviewPane when files non-empty', (tester) async {
    final files = [_ef('/a.jpg'), _ef('/b.jpg'), _ef('/c.jpg')];
    final seeded = FilesTabState.initial().copyWith(
      files: files,
      match: MatchedSelection.empty(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesTabNotifierProvider.overrideWith(
            (ref) => _SeededFilesTabNotifier(seeded),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FilesTab())),
      ),
    );
    expect(find.byType(FileReviewPane), findsOneWidget);
    // The empty-state hint should not be visible when files are staged.
    expect(find.textContaining('Pick files or'), findsNothing);
  });
}
