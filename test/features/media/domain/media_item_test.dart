import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

MediaItem _baseItem() => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  group('MediaItem source-type fields', () {
    test('default sourceType is platformGallery for backwards compat', () {
      final item = MediaItem(
        id: 'x',
        mediaType: MediaType.photo,
        // sourceType intentionally omitted — should default to platformGallery
        takenAt: DateTime.utc(2024, 1, 1),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      expect(item.sourceType, MediaSourceType.platformGallery);
    });

    test('copyWith updates new pointer fields', () {
      final base = _baseItem();
      final updated = base.copyWith(
        sourceType: MediaSourceType.localFile,
        localPath: '/Users/me/x.jpg',
        originDeviceId: 'mac-01',
      );
      expect(updated.sourceType, MediaSourceType.localFile);
      expect(updated.localPath, '/Users/me/x.jpg');
      expect(updated.originDeviceId, 'mac-01');
    });

    test('copyWith preserves unset pointer fields', () {
      final base = _baseItem().copyWith(
        sourceType: MediaSourceType.networkUrl,
        url: 'https://example.com/x.jpg',
      );
      final updated = base.copyWith(caption: 'a caption');
      expect(updated.url, 'https://example.com/x.jpg');
      expect(updated.sourceType, MediaSourceType.networkUrl);
      expect(updated.caption, 'a caption');
    });

    test('copyWith can clear nullable pointer fields by passing null', () {
      final base = _baseItem().copyWith(
        sourceType: MediaSourceType.localFile,
        localPath: '/x.jpg',
      );
      final updated = base.copyWith(localPath: null);
      expect(updated.localPath, isNull);
    });

    test('equality includes new fields', () {
      final a = _baseItem().copyWith(localPath: '/x.jpg');
      final b = _baseItem().copyWith(localPath: '/x.jpg');
      final c = _baseItem().copyWith(localPath: '/y.jpg');
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
