import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

void main() {
  MediaItem item({
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? remoteUploadedAt,
    DateTime? remoteCompressedUploadedAt,
    DateTime? remoteThumbUploadedAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: sourceType,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    remoteUploadedAt: remoteUploadedAt,
    remoteCompressedUploadedAt: remoteCompressedUploadedAt,
    remoteThumbUploadedAt: remoteThumbUploadedAt,
  );

  final stamp = DateTime(2026, 6, 1);

  group('isBackedUp', () {
    test('false when every remote stamp is null', () {
      expect(isBackedUp(item()), isFalse);
    });

    test('true on remoteUploadedAt alone', () {
      expect(isBackedUp(item(remoteUploadedAt: stamp)), isTrue);
    });

    test('true on remoteCompressedUploadedAt alone', () {
      expect(isBackedUp(item(remoteCompressedUploadedAt: stamp)), isTrue);
    });

    test('a thumb stamp alone does not back up a normal photo', () {
      expect(isBackedUp(item(remoteThumbUploadedAt: stamp)), isFalse);
    });

    test('a connector video is backed up by its thumb stamp alone', () {
      expect(
        isBackedUp(
          item(
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
            remoteThumbUploadedAt: stamp,
          ),
        ),
        isTrue,
      );
    });

    test('a connector video with no thumb stamp is not backed up', () {
      expect(
        isBackedUp(
          item(
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
            remoteUploadedAt: stamp,
          ),
        ),
        isFalse,
      );
    });

    test('a local video follows the original-stamp rule, not thumb-only', () {
      expect(
        isBackedUp(item(mediaType: MediaType.video, remoteUploadedAt: stamp)),
        isTrue,
      );
      expect(
        isBackedUp(
          item(mediaType: MediaType.video, remoteThumbUploadedAt: stamp),
        ),
        isFalse,
      );
    });
  });

  group('kUploadableSources', () {
    test('includes the three uploadable sources', () {
      expect(
        kUploadableSources,
        containsAll(<MediaSourceType>[
          MediaSourceType.platformGallery,
          MediaSourceType.localFile,
          MediaSourceType.serviceConnector,
        ]),
      );
    });

    test('excludes sources that are never uploaded', () {
      expect(kUploadableSources, isNot(contains(MediaSourceType.networkUrl)));
      expect(
        kUploadableSources,
        isNot(contains(MediaSourceType.manifestEntry)),
      );
      expect(kUploadableSources, isNot(contains(MediaSourceType.signature)));
    });
  });
}
