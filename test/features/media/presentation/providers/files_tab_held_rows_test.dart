import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';

import 'files_tab_providers_test.mocks.dart';

ExtractedFile _ef(String path) => ExtractedFile(
  sourcePath: path,
  file: File(path),
  metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
);

/// The Files tab opened from a sitting on a dive: the rows it would write
/// for that dive, and none written (issue #4527, plan 6).
void main() {
  late MockMediaRepository repo;
  late MockLocalBookmarkStorage bookmarks;
  late MockLocalMediaPlatform platform;
  late ProviderContainer container;

  setUp(() {
    repo = MockMediaRepository();
    bookmarks = MockLocalBookmarkStorage();
    platform = MockLocalMediaPlatform();
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(repo),
        localBookmarkStorageProvider.overrideWithValue(bookmarks),
        localMediaPlatformProvider.overrideWithValue(platform),
        mediaStoreEnqueueProvider.overrideWithValue((_) {}),
      ],
    );
    when(
      platform.createBookmark(any),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    when(bookmarks.write(any, any)).thenAnswer((_) async {});
  });
  tearDown(() => container.dispose());

  test("heldRows builds this dive's rows, writes none, and counts the "
      'others', () async {
    final notifier = container.read(filesTabNotifierProvider.notifier);
    final a = _ef('/a.jpg');
    final b = _ef('/b.jpg');
    final c = _ef('/c.jpg');
    notifier.setFiles(
      [a, b, c],
      match: MatchedSelection(
        matched: {
          'd1': [a],
          'd2': [b, c],
        },
        unmatched: const [],
      ),
    );

    final held = await notifier.heldRows('d1');

    expect(held.leftOut, 2);
    final row = held.rows.single;
    expect(row.diveId, 'd1');
    expect(row.id, isNotEmpty);
    expect(row.sourceType, MediaSourceType.localFile);
    expect(row.originalFilename, 'a.jpg');
    verifyNever(repo.createMedia(any));
  });

  test(
    "heldSiteRows builds every staged file as the site's, writes none",
    () async {
      final notifier = container.read(filesTabNotifierProvider.notifier);
      final a = _ef('/a.jpg');
      final b = _ef('/b.jpg');
      // A site has no dives: the matcher's grouping is ignored, as commit
      // ignores it for a site.
      notifier.setFiles(
        [a, b],
        match: MatchedSelection(
          matched: {
            'd1': [a],
          },
          unmatched: [b],
        ),
      );

      final rows = await notifier.heldSiteRows('s1');

      expect(rows.map((r) => r.originalFilename), ['a.jpg', 'b.jpg']);
      expect(rows.every((r) => r.siteId == 's1' && r.diveId == null), isTrue);
      expect(rows.every((r) => r.id.isNotEmpty), isTrue);
      verifyNever(repo.createMedia(any));
    },
  );
}
