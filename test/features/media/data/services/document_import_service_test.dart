import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/document_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../presentation/providers/files_tab_providers_test.mocks.dart';

void main() {
  late MockMediaRepository mockRepository;
  late MockLocalMediaPlatform mockPlatform;
  late MockLocalBookmarkStorage mockStorage;
  late List<String> createdIds;
  late DocumentImportService service;

  setUp(() {
    mockRepository = MockMediaRepository();
    mockPlatform = MockLocalMediaPlatform();
    mockStorage = MockLocalBookmarkStorage();
    createdIds = [];
    service = DocumentImportService(
      mediaRepository: mockRepository,
      platform: mockPlatform,
      bookmarkStorage: mockStorage,
      onMediaCreated: createdIds.add,
    );
    when(
      mockPlatform.createBookmark(any),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    when(mockStorage.write(any, any)).thenAnswer((_) async {});
    var counter = 0;
    when(mockRepository.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'doc-${counter++}');
    });
  });

  test('imports a pdf as a document media row linked to the site', () async {
    final created = await service.importDocuments(
      picked: [
        (path: '/tmp/reef-map.pdf', filename: 'reef-map.pdf', identifier: null),
      ],
      siteId: 'site-1',
    );

    expect(created, hasLength(1));
    final item = created.single;
    expect(item.mediaType, MediaType.document);
    expect(item.siteId, 'site-1');
    expect(item.diveId, isNull);
    expect(item.sourceType, MediaSourceType.localFile);
    expect(item.originalFilename, 'reef-map.pdf');
    expect(item.isPdf, isTrue);
  });

  test('links to a dive when diveId is given', () async {
    final created = await service.importDocuments(
      picked: [
        (path: '/tmp/waiver.pdf', filename: 'waiver.pdf', identifier: null),
      ],
      diveId: 'dive-1',
    );

    expect(created.single.diveId, 'dive-1');
    expect(created.single.siteId, isNull);
  });

  test('fires onMediaCreated per row for media-store enqueue', () async {
    await service.importDocuments(
      picked: [
        (path: '/tmp/a.pdf', filename: 'a.pdf', identifier: null),
        (path: '/tmp/b.txt', filename: 'b.txt', identifier: null),
      ],
      siteId: 'site-1',
    );

    expect(createdIds, ['doc-0', 'doc-1']);
  });

  test('on this host the platform reference matches the OS branch', () async {
    // The suite runs on macOS (bookmark) or Linux CI (plain path); both
    // must produce a resolvable reference.
    final created = await service.importDocuments(
      picked: [(path: '/tmp/map.pdf', filename: 'map.pdf', identifier: null)],
      siteId: 'site-1',
    );
    final item = created.single;
    expect(
      (item.bookmarkRef != null) || (item.localPath != null),
      isTrue,
      reason: 'a document row must carry a bookmark or a path',
    );
  });

  // The Android branch is the one issue #1002 was filed against and it can
  // only run on an Android host, so it is driven through the injected
  // strategy seam here (same reason LocalFileResolver injects
  // usesSecurityScopedBookmarks).
  group('persistable-URI host (Android)', () {
    late DocumentImportService android;

    setUp(() {
      android = DocumentImportService(
        mediaRepository: mockRepository,
        platform: mockPlatform,
        bookmarkStorage: mockStorage,
        onMediaCreated: createdIds.add,
        refStrategy: () => DocumentRefStrategy.persistableUri,
      );
    });

    test(
      'persists the SAF content URI, not the file_picker cache copy',
      () async {
        when(
          mockPlatform.takePersistableUri(any),
        ).thenAnswer((i) async => i.positionalArguments.first as String);

        const uri =
            'content://com.android.providers.downloads.documents/document/42';
        final created = await android.importDocuments(
          picked: [
            (
              path: '/data/user/0/app.submersion/cache/file_picker/1/reef.pdf',
              filename: 'reef.pdf',
              identifier: uri,
            ),
          ],
          siteId: 'site-1',
        );

        verify(mockPlatform.takePersistableUri(uri)).called(1);
        expect(created.single.bookmarkRef, uri);
        expect(created.single.localPath, isNull);
      },
    );

    test(
      'never hands the cache path to takePersistableUri (issue #1002)',
      () async {
        final created = await android.importDocuments(
          picked: [
            (
              path: '/data/user/0/app.submersion/cache/file_picker/1/reef.pdf',
              filename: 'reef.pdf',
              identifier: null,
            ),
          ],
          siteId: 'site-1',
        );

        verifyNever(mockPlatform.takePersistableUri(any));
        expect(created.single.bookmarkRef, isNull);
        expect(
          created.single.localPath,
          '/data/user/0/app.submersion/cache/file_picker/1/reef.pdf',
        );
      },
    );

    test('falls back to the picked path when the grant is refused', () async {
      when(mockPlatform.takePersistableUri(any)).thenThrow(
        PlatformException(
          code: 'PERMISSION_DENIED',
          message:
              'No persistable permission grants found for UID 10491 '
              'and Uri ',
        ),
      );

      final created = await android.importDocuments(
        picked: [
          (
            path: '/data/user/0/app.submersion/cache/file_picker/1/reef.pdf',
            filename: 'reef.pdf',
            identifier: 'content://an.unpersistable.provider/doc/7',
          ),
        ],
        siteId: 'site-1',
      );

      expect(created, hasLength(1));
      expect(created.single.bookmarkRef, isNull);
      expect(
        created.single.localPath,
        '/data/user/0/app.submersion/cache/file_picker/1/reef.pdf',
      );
    });
  });
}
