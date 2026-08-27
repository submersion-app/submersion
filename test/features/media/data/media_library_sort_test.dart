import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late MediaRepository mediaRepo;
  late MediaLibraryRepository repo;

  Future<void> insertMedia(
    String id,
    DateTime takenAt, {
    String? originalFilename,
    int? contentSizeBytes,
  }) => mediaRepo.createMedia(
    MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: '/tmp/$id',
      localPath: '/tmp/$id',
      originalFilename: originalFilename,
      contentSizeBytes: contentSizeBytes,
      // Production normalises to wall-clock-as-UTC before persisting, so the
      // fixture has to as well or the date assertions pass or fail by host
      // timezone.
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  setUp(() async {
    await setUpTestDatabase();
    mediaRepo = MediaRepository();
    repo = MediaLibraryRepository();

    // Five unlinked rows, no diver scoping needed. Two carry a null filename
    // and two a null size, so every sort key exercises its COALESCE fallback
    // and pages across a run of rows whose raw column is NULL.
    await insertMedia(
      'a',
      DateTime(2026, 6, 1),
      originalFilename: 'alpha.jpg',
      contentSizeBytes: 500,
    );
    await insertMedia(
      'b',
      DateTime(2026, 6, 2),
      originalFilename: 'bravo.jpg',
      contentSizeBytes: 100,
    );
    await insertMedia('c', DateTime(2026, 6, 3), contentSizeBytes: 300);
    await insertMedia('d', DateTime(2026, 6, 4), originalFilename: 'delta.jpg');
    await insertMedia('e', DateTime(2026, 6, 5));
  });
  tearDown(tearDownTestDatabase);

  /// Walks every page with the given sort and returns the ids in order.
  Future<List<String>> pageThrough(
    SortState<MediaSortField> sort, {
    int limit = 2,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    final ids = <String>[];
    MediaLibraryCursor? cursor;
    var guard = 0;
    while (true) {
      final page = await repo.getPage(
        diverId: null,
        filter: filter,
        sort: sort,
        after: cursor,
        limit: limit,
      );
      ids.addAll(page.entries.map((e) => e.item.id));
      cursor = page.nextCursor;
      if (cursor == null) break;
      if (++guard > 20) fail('pagination did not terminate');
    }
    return ids;
  }

  SortState<MediaSortField> sortBy(
    MediaSortField field,
    SortDirection direction,
  ) => SortState(field: field, direction: direction);

  group('date sort', () {
    test('descending is the default and is unchanged', () async {
      final page = await repo.getPage(diverId: null);
      expect(page.entries.map((e) => e.item.id), ['e', 'd', 'c', 'b', 'a']);
    });

    test('ascending reverses it', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.dateTaken, SortDirection.ascending),
        ),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });
  });

  group('file name sort', () {
    // Rows with no originalFilename fall back to file_path ('/tmp/c',
    // '/tmp/e'), which sorts before every bare 'x.jpg' name.
    test('ascending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.ascending),
        ),
        ['c', 'e', 'a', 'b', 'd'],
      );
    });

    test('descending is the exact reverse', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileName, SortDirection.descending),
        ),
        ['d', 'b', 'a', 'e', 'c'],
      );
    });
  });

  group('file size sort', () {
    // 'd' and 'e' have no size and coalesce to -1, so they sort smallest.
    // Their tie is broken by id in the direction of the sort.
    test('descending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileSize, SortDirection.descending),
        ),
        ['a', 'c', 'b', 'e', 'd'],
      );
    });

    test('ascending pages through every row exactly once', () async {
      expect(
        await pageThrough(
          sortBy(MediaSortField.fileSize, SortDirection.ascending),
        ),
        ['d', 'e', 'b', 'c', 'a'],
      );
    });

    test('a tie in the sort key does not drop or repeat rows', () async {
      // Two more rows sharing a size with an existing one. A keyset whose
      // tiebreaker is wrong silently loses one of them.
      await insertMedia(
        'f',
        DateTime(2026, 6, 6),
        originalFilename: 'foxtrot.jpg',
        contentSizeBytes: 300,
      );
      await insertMedia(
        'g',
        DateTime(2026, 6, 7),
        originalFilename: 'golf.jpg',
        contentSizeBytes: 300,
      );

      final ids = await pageThrough(
        sortBy(MediaSortField.fileSize, SortDirection.descending),
      );
      expect(ids, hasLength(7));
      expect(ids.toSet(), hasLength(7));
      expect(ids.take(4), ['a', 'g', 'f', 'c']);
    });
  });

  group('date bounds are independent of the sort key', () {
    test('a date range still filters by date while sorting by size', () async {
      final filter = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 2),
        toDate: DateTime(2026, 6, 4, 23, 59, 59, 999),
      );
      final ids = await pageThrough(
        sortBy(MediaSortField.fileSize, SortDirection.descending),
        filter: filter,
      );
      // b (100), c (300), d (null) are in range; a and e are outside it.
      expect(ids, ['c', 'b', 'd']);
    });

    test('a date range still filters by date while sorting by name', () async {
      final filter = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 2),
        toDate: DateTime(2026, 6, 4, 23, 59, 59, 999),
      );
      final ids = await pageThrough(
        sortBy(MediaSortField.fileName, SortDirection.ascending),
        filter: filter,
      );
      expect(ids, ['c', 'b', 'd']);
    });
  });
}
