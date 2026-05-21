import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

import 'local_media_linker_test.mocks.dart';

@GenerateMocks([MediaRepository, LocalBookmarkStorage])
void main() {
  late MockMediaRepository repo;
  late MockLocalBookmarkStorage bookmarkStorage;
  late LocalMediaLinker linker;

  setUp(() {
    repo = MockMediaRepository();
    bookmarkStorage = MockLocalBookmarkStorage();
    linker = LocalMediaLinker(
      mediaRepository: repo,
      bookmarkStorage: bookmarkStorage,
    );
    when(repo.createMedia(any)).thenAnswer((inv) async {
      final item = inv.positionalArguments.single as MediaItem;
      return item.copyWith(id: item.id.isEmpty ? 'generated-id' : item.id);
    });
  });

  test(
    'desktop handle: persists localPath, no bookmark side effects',
    () async {
      final created = await linker.link(
        diveId: 'dive-1',
        handle: const MediaHandle.localPath('/picked/shark.jpg'),
        basename: 'shark.jpg',
        metadata: const MediaSourceMetadata(
          mimeType: 'image/jpeg',
          latitude: 1.5,
          longitude: -2.5,
          width: 800,
          height: 600,
        ),
        caption: 'Reef shark',
        fallbackTakenAt: DateTime(2020, 1, 1),
      );

      expect(created.id, 'generated-id');
      final captured =
          verify(repo.createMedia(captureAny)).captured.single as MediaItem;
      expect(captured.diveId, 'dive-1');
      expect(captured.sourceType, MediaSourceType.localFile);
      expect(captured.mediaType, MediaType.photo);
      expect(captured.localPath, '/picked/shark.jpg');
      expect(captured.filePath, '/picked/shark.jpg');
      expect(captured.bookmarkRef, isNull);
      expect(captured.originalFilename, 'shark.jpg');
      expect(captured.caption, 'Reef shark');
      expect(captured.latitude, 1.5);
      expect(captured.longitude, -2.5);
      expect(captured.width, 800);
      expect(captured.height, 600);
      verifyNever(bookmarkStorage.write(any, any));
    },
  );

  test(
    'android handle: persists bookmarkRef from content URI, null localPath',
    () async {
      await linker.link(
        diveId: 'dive-2',
        handle: const MediaHandle.contentUri('content://tree/doc/42'),
        basename: 'turtle.jpg',
        metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
        fallbackTakenAt: DateTime(2020),
      );
      final captured =
          verify(repo.createMedia(captureAny)).captured.single as MediaItem;
      expect(captured.bookmarkRef, 'content://tree/doc/42');
      expect(captured.localPath, isNull);
      expect(captured.sourceType, MediaSourceType.localFile);
    },
  );

  test('iOS handle: stores bookmark blob under a generated key', () async {
    await linker.link(
      diveId: 'dive-3',
      handle: MediaHandle.bookmark(Uint8List.fromList([9, 9, 9])),
      basename: 'eel.jpg',
      metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
      fallbackTakenAt: DateTime(2020),
    );
    final keyCap = verify(bookmarkStorage.write(captureAny, any)).captured;
    expect(keyCap.single, isA<String>());
    final captured =
        verify(repo.createMedia(captureAny)).captured.single as MediaItem;
    expect(captured.bookmarkRef, isNotEmpty);
    expect(captured.localPath, isNull);
  });

  test('falls back to fallbackTakenAt when metadata.takenAt is null', () async {
    await linker.link(
      diveId: 'dive-4',
      handle: const MediaHandle.localPath('/picked/a.jpg'),
      basename: 'a.jpg',
      metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
      fallbackTakenAt: DateTime(2019, 6, 1),
    );
    final captured =
        verify(repo.createMedia(captureAny)).captured.single as MediaItem;
    expect(captured.takenAt, DateTime(2019, 6, 1));
  });

  test('macOS handle: stores bookmark blob AND localPath', () async {
    await linker.link(
      diveId: 'dive-5',
      handle: MediaHandle(
        bookmarkBlob: Uint8List.fromList([1, 2, 3]),
        localPath: '/Users/me/Pictures/coral.jpg',
      ),
      basename: 'coral.jpg',
      metadata: const MediaSourceMetadata(mimeType: 'image/jpeg'),
      fallbackTakenAt: DateTime(2020),
    );
    final keyCap = verify(bookmarkStorage.write(captureAny, any)).captured;
    expect(keyCap.single, isA<String>());
    final captured =
        verify(repo.createMedia(captureAny)).captured.single as MediaItem;
    expect(captured.bookmarkRef, isNotEmpty);
    expect(captured.localPath, '/Users/me/Pictures/coral.jpg');
    expect(captured.filePath, '/Users/me/Pictures/coral.jpg');
  });
}
