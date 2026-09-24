import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

/// Hands out a cached mapping whose asset no longer reads, then [_again]
/// when the resolver drops it and searches again.
class _StaleCacheService extends AssetResolutionService {
  _StaleCacheService(this._again)
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: FakePhotoPickerService(),
      );

  final ResolutionResult _again;
  int reresolves = 0;

  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) async =>
      const ResolutionResult(
        localAssetId: 'cached',
        status: ResolutionStatus.resolved,
      );

  @override
  Future<ResolutionResult> reresolve(MediaItem item) async {
    reresolves++;
    return _again;
  }
}

/// A cached mapping is trusted without re-proving it, so a photo can stop
/// reading under it: dropped from a limited selection, or re-indexed. That
/// is a reason to search again, never proof the photo is gone (media sync
/// program spec 6.3).
void main() {
  late FakePhotoPickerService library;

  setUp(() => library = FakePhotoPickerService());

  /// Linked on this device, so a genuine miss here would be notFound.
  MediaItem row() => MediaItem(
    id: 'x',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'A-1',
    originDeviceId: 'this-device',
    takenAt: DateTime.utc(2024, 1, 1),
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
  );

  PlatformGalleryResolver resolver(AssetResolutionService service) =>
      PlatformGalleryResolver(
        resolutionService: service,
        assetReader: library,
        localDeviceId: () async => 'this-device',
      );

  const limited = ResolutionResult(
    status: ResolutionStatus.accessDenied,
    limitedAccess: true,
  );

  test(
    'a cached photo dropped from the selection is limited, not gone',
    () async {
      final service = _StaleCacheService(limited);

      final data = await resolver(service).resolve(row());

      expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
      expect(data.limitedAccess, isTrue);
      expect(service.reresolves, 1);
    },
  );

  test('a cached photo re-found under a new id is served', () async {
    library.add(
      FakeGalleryAsset(
        id: 'B-2',
        bytes: Uint8List.fromList([5]),
        takenAt: DateTime(2024),
      ),
    );
    final service = _StaleCacheService(
      const ResolutionResult(
        localAssetId: 'B-2',
        status: ResolutionStatus.resolved,
      ),
    );

    final data = await resolver(service).resolve(row());

    expect((data as BytesData).bytes, [5]);
  });

  test('a cached photo the search cannot find is still missing', () async {
    final service = _StaleCacheService(
      const ResolutionResult(status: ResolutionStatus.unavailable),
    );

    final data = await resolver(service).resolve(row());

    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('verify finds a cached photo re-found under a new id', () async {
    library.add(
      FakeGalleryAsset(
        id: 'B-2',
        bytes: Uint8List.fromList([5]),
        takenAt: DateTime(2024),
      ),
    );
    final service = _StaleCacheService(
      const ResolutionResult(
        localAssetId: 'B-2',
        status: ResolutionStatus.resolved,
      ),
    );

    expect(await resolver(service).verify(row()), VerifyResult.available);
  });

  test('verify re-searches a cached photo that no longer exists', () async {
    final service = _StaleCacheService(limited);

    expect(await resolver(service).verify(row()), VerifyResult.accessDenied);
    expect(service.reresolves, 1);
  });
}
