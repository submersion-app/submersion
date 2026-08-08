import 'dart:io';

import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/media_store_source_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

MediaItem item({String? contentHash, DateTime? remoteUploadedAt}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
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
