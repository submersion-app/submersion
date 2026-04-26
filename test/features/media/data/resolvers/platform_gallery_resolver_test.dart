import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _gallery({String? assetId, String? originDeviceId}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: assetId,
  originDeviceId: originDeviceId,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  test('canResolveOnThisDevice is always true for gallery items', () {
    final r = PlatformGalleryResolver();
    expect(r.canResolveOnThisDevice(_gallery(assetId: 'A')), isTrue);
    expect(r.canResolveOnThisDevice(_gallery(originDeviceId: 'other')), isTrue);
  });

  test('resolve returns Unavailable.notFound when assetId missing', () async {
    final r = PlatformGalleryResolver();
    final data = await r.resolve(_gallery(assetId: null));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('resolve returns Unavailable.notFound when assetId empty', () async {
    final r = PlatformGalleryResolver();
    final data = await r.resolve(_gallery(assetId: ''));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('extractMetadata returns null when assetId missing', () async {
    final r = PlatformGalleryResolver();
    final m = await r.extractMetadata(_gallery(assetId: null));
    expect(m, isNull);
  });

  test('verify returns notFound when assetId missing', () async {
    final r = PlatformGalleryResolver();
    final v = await r.verify(_gallery(assetId: null));
    expect(v.toString(), contains('notFound'));
  });
}
