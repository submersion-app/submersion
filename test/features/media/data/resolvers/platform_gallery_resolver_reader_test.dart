import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late FakePhotoPickerService gallery;
  late PlatformGalleryResolver resolver;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    gallery = FakePhotoPickerService(
      assets: [FakeGalleryAsset(id: 'A-1', bytes: bytes, takenAt: taken)],
    );
    resolver = PlatformGalleryResolver(
      localDeviceId: () async => 'this-device',
      resolutionService: AssetResolutionService(
        cacheRepository: LocalAssetCacheRepository(database: cacheDb),
        photoPickerService: gallery,
      ),
      assetReader: gallery,
    );
  });

  tearDown(() => cacheDb.close());

  // Rows here were linked on this device: a miss is evidence of absence
  // only there (media sync program spec 6.1).
  MediaItem row(
    String assetId, {
    DateTime? takenAt,
    String filename = 'IMG_0001.JPG',
    String? originDeviceId = 'this-device',
  }) => MediaItem(
    id: 'm-$assetId',
    platformAssetId: assetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    originalFilename: filename,
    originDeviceId: originDeviceId,
    takenAt: takenAt ?? taken,
    createdAt: taken,
    updatedAt: taken,
  );

  test('serves origin bytes through the reader', () async {
    final data = await resolver.resolve(row('A-1'));
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, bytes);
  });

  test('verify answers available through the reader', () async {
    expect(await resolver.verify(row('A-1')), VerifyResult.available);
  });

  test('an id the library never had is notFound', () async {
    // A different capture time and name, so no metadata tier can re-find
    // it: the tiers exist precisely to match a foreign id to a local one.
    final data = await resolver.resolve(
      row(
        'Z-9',
        takenAt: taken.add(const Duration(days: 3)),
        filename: 'IMG_9999.JPG',
      ),
    );
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('a foreign id with matching metadata is re-found and served', () async {
    final data = await resolver.resolve(row('other-device-id'));
    expect(data, isA<BytesData>());
  });

  test('serves thumbnail bytes through the reader', () async {
    final data = await resolver.resolveThumbnail(
      row('A-1'),
      target: const Size(200, 200),
    );
    expect(data, isA<BytesData>());
    final bytesData = data as BytesData;
    expect(bytesData.bytes, bytes);
    expect(bytesData.servedTier, ServedTier.thumbnail);
  });

  test(
    'verify answers notFound once the reader says the asset is gone',
    () async {
      // Resolve once so the local id is cached, then remove the asset: the
      // cache still hands back the id and the reader is what reports it gone.
      expect(await resolver.verify(row('A-1')), VerifyResult.available);
      gallery.remove('A-1');
      expect(await resolver.verify(row('A-1')), VerifyResult.notFound);
    },
  );

  test('metadata comes from the reader', () async {
    final meta = await resolver.extractMetadata(row('A-1'));
    expect(meta, isNotNull);
    expect(meta!.width, 4032);
    expect(meta.takenAt, taken);
  });
}
