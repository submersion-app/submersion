import 'dart:io';

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/media_store_source_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

MediaItem item({
  String? contentHash,
  DateTime? remoteUploadedAt,
  MediaType mediaType = MediaType.photo,
}) => MediaItem(
  id: 'm1',
  mediaType: mediaType,
  sourceType: MediaSourceType.mediaStore,
  contentHash: contentHash,
  remoteUploadedAt: remoteUploadedAt,
  takenAt: DateTime.utc(2026, 6, 1),
  createdAt: DateTime.utc(2026, 6, 1),
  updatedAt: DateTime.utc(2026, 6, 1),
);

void main() {
  test(
    'resolve returns UnavailableData(unauthenticated) with no store',
    () async {
      final resolver = MediaStoreSourceResolver(remote: () => null);
      final data = await resolver.resolve(item());
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.unauthenticated);
    },
  );

  test(
    'resolve delegates to the remote resolve with thumbnail false',
    () async {
      bool? seenThumbnail;
      final file = File('${Directory.systemTemp.path}/store-src-test.jpg');
      final resolver = MediaStoreSourceResolver(
        remote: () => (mediaItem, {required bool thumbnail}) async {
          seenThumbnail = thumbnail;
          return FileData(file: file);
        },
      );
      final data = await resolver.resolve(item());
      expect(seenThumbnail, isFalse);
      expect(data, isA<FileData>());
    },
  );

  test('resolveThumbnail asks for the thumbnail variant', () async {
    bool? seenThumbnail;
    final file = File('${Directory.systemTemp.path}/store-src-test.jpg');
    final resolver = MediaStoreSourceResolver(
      remote: () => (mediaItem, {required bool thumbnail}) async {
        seenThumbnail = thumbnail;
        return FileData(file: file);
      },
    );
    await resolver.resolveThumbnail(item(), target: const Size(100, 100));
    expect(seenThumbnail, isTrue);
  });

  test('a null remote result becomes UnavailableData(notFound)', () async {
    final resolver = MediaStoreSourceResolver(
      remote: () =>
          (mediaItem, {required bool thumbnail}) async => null,
    );
    final data = await resolver.resolve(item());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  /// `MediaStoreResolver.tryResolveRemote` declines a video thumbnail on
  /// purpose rather than download the original for a grid tile. Falling
  /// through to `resolve` undoes that, one full video per tile.
  test('a video thumbnail never degrades to the original', () async {
    final seen = <bool>[];
    final resolver = MediaStoreSourceResolver(
      remote: () => (mediaItem, {required bool thumbnail}) async {
        seen.add(thumbnail);
        return null;
      },
    );

    final data = await resolver.resolveThumbnail(
      item(mediaType: MediaType.video),
      target: const Size(140, 140),
    );

    expect(seen, [
      true,
    ], reason: 'asking again with thumbnail:false is a full video download');
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('a photo thumbnail still degrades to the original', () async {
    final seen = <bool>[];
    final file = File('${Directory.systemTemp.path}/store-src-test.jpg');
    final resolver = MediaStoreSourceResolver(
      remote: () => (mediaItem, {required bool thumbnail}) async {
        seen.add(thumbnail);
        return thumbnail ? null : FileData(file: file);
      },
    );

    final data = await resolver.resolveThumbnail(
      item(),
      target: const Size(140, 140),
    );

    expect(seen, [true, false]);
    expect(data, isA<FileData>());
  });

  test('a video thumbnail that the store does have is served', () async {
    final file = File('${Directory.systemTemp.path}/store-src-poster.jpg');
    final seen = <bool>[];
    final resolver = MediaStoreSourceResolver(
      remote: () => (mediaItem, {required bool thumbnail}) async {
        seen.add(thumbnail);
        return FileData(file: file, isPoster: true);
      },
    );

    final data = await resolver.resolveThumbnail(
      item(mediaType: MediaType.video),
      target: const Size(140, 140),
    );

    expect(seen, [true]);
    expect((data as FileData).isPoster, isTrue);
  });

  test('verify never orphans when the store is unavailable', () async {
    final resolver = MediaStoreSourceResolver(remote: () => null);
    expect(await resolver.verify(item()), VerifyResult.transientError);
  });

  test('verify reflects the stamp pair when the store is configured', () async {
    final resolver = MediaStoreSourceResolver(
      remote: () =>
          (mediaItem, {required bool thumbnail}) async => null,
    );
    expect(
      await resolver.verify(
        item(contentHash: 'h', remoteUploadedAt: DateTime.utc(2026)),
      ),
      VerifyResult.available,
    );
    expect(await resolver.verify(item()), VerifyResult.notFound);
  });
}
