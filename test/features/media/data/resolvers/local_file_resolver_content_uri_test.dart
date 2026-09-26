import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null as dynamic);
}

/// Android's content-URI read, failing the way the native handler reports:
/// `PERMISSION_DENIED` for a SecurityException (the read grant is gone),
/// `READ_FAILED` for anything else.
class _FailingUriPlatform extends LocalMediaPlatform {
  _FailingUriPlatform(this.code);

  final String code;

  @override
  Future<Uint8List> readUriBytes(String uri) async =>
      throw PlatformException(code: code, message: 'denied');
}

/// On Android a file link is a content URI. When it stops reading on the
/// device that linked it, the photo library is searched by metadata before
/// anything is decided, and a lost grant is never proof the file is gone
/// (media sync program spec 6.3).
void main() {
  final recovered = BytesData(bytes: Uint8List.fromList([7]));

  MediaItem row({String origin = 'me'}) => MediaItem(
    id: 'f1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    bookmarkRef: 'content://media/external/images/media/42',
    originDeviceId: origin,
    takenAt: DateTime.utc(2026, 7, 1),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  var searches = 0;
  setUp(() => searches = 0);

  LocalFileResolver resolver(String code, {MediaSourceData? found}) =>
      LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: _FailingUriPlatform(code),
        exifExtractor: ExifExtractor(),
        readsContentUris: () => true,
        localDeviceId: () async => 'me',
        findInLibrary: (item) async {
          searches++;
          return found;
        },
      );

  test('a lost grant the library search recovers serves the photo', () async {
    final data = await resolver(
      'PERMISSION_DENIED',
      found: recovered,
    ).resolve(row());

    expect(data, recovered);
  });

  test('a lost grant the search cannot recover is inconclusive', () async {
    final data = await resolver('PERMISSION_DENIED').resolve(row());

    expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
    expect(searches, 1);
  });

  test('a failed read the search cannot recover is notFound', () async {
    final data = await resolver('READ_FAILED').resolve(row());

    expect((data as UnavailableData).kind, UnavailableKind.notFound);
    expect(searches, 1);
  });

  // The search could not look (no permission, a failed query, a limited
  // selection): a failed read is then inconclusive too, not notFound.
  test('an inconclusive search keeps a failed read inconclusive', () async {
    final data = await resolver(
      'READ_FAILED',
      found: const UnavailableData(kind: UnavailableKind.accessDenied),
    ).resolve(row());

    expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
  });

  // A search that throws said nothing about the file: the read's own
  // verdict stands, and the render does not fail.
  test(
    'a library search that throws falls back to the read\'s verdict',
    () async {
      final data = await LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: _FailingUriPlatform('PERMISSION_DENIED'),
        exifExtractor: ExifExtractor(),
        readsContentUris: () => true,
        localDeviceId: () async => 'me',
        findInLibrary: (item) async => throw StateError('channel'),
      ).resolve(row());

      expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
    },
  );

  // Another device's content URI never had a grant here, so it is not a
  // lost grant and not worth a library search per render.
  test('another device\'s content URI is not searched', () async {
    final data = await resolver(
      'PERMISSION_DENIED',
      found: recovered,
    ).resolve(row(origin: 'peer'));

    expect((data as UnavailableData).kind, UnavailableKind.fromOtherDevice);
    expect(searches, 0);
  });

  // The verification sweep would otherwise read an inconclusive answer as
  // notFound and orphan the row.
  test('verify reports a lost grant as accessDenied', () async {
    expect(
      await resolver('PERMISSION_DENIED').verify(row()),
      VerifyResult.accessDenied,
    );
  });
}
