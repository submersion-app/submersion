import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';

MediaItem _item({int? width, int? height, MediaType type = MediaType.photo}) =>
    MediaItem(
      id: 'm',
      mediaType: type,
      sourceType: MediaSourceType.localFile,
      width: width,
      height: height,
      takenAt: DateTime.utc(2026, 5, 2),
      createdAt: DateTime.utc(2026, 5, 2),
      updatedAt: DateTime.utc(2026, 5, 2),
    );

/// The shape each library thumbnail is laid out at (issue #4738).
void main() {
  group('mediaRawAspect', () {
    test('uses the stored size', () {
      expect(mediaRawAspect(_item(width: 4000, height: 3000)), 4 / 3);
    });

    test('prefers a ratio learned against the same stored size', () {
      final item = _item(width: 3000, height: 4000);
      expect(
        mediaRawAspect(item, learned: (ratio: 0.75, width: 3000, height: 4000)),
        0.75,
      );
    });

    test('ignores a ratio learned against another stored size', () {
      final item = _item(width: 3000, height: 4000);
      expect(
        mediaRawAspect(
          item,
          learned: (ratio: 4 / 3, width: 4000, height: 3000),
        ),
        0.75,
      );
    });

    test('falls back to 4:3 without a usable stored size', () {
      expect(mediaRawAspect(_item(height: 3000)), 4 / 3);
      expect(mediaRawAspect(_item(width: 0, height: 3000)), 4 / 3);
    });

    test('learns an item with no stored size', () {
      expect(
        mediaRawAspect(
          _item(),
          learned: (ratio: 0.5, width: null, height: null),
        ),
        0.5,
      );
    });

    test('lays a document out at 3:4 whatever is stored or learned', () {
      final doc = _item(width: 1000, height: 100, type: MediaType.document);
      expect(mediaRawAspect(doc), 0.75);
      expect(
        mediaRawAspect(doc, learned: (ratio: 2, width: 1000, height: 100)),
        0.75,
      );
    });
  });

  test('clampMediaAspect keeps shapes within 1:3 and 3:1', () {
    expect(clampMediaAspect(5), 3);
    expect(clampMediaAspect(0.1), 1 / 3);
    expect(clampMediaAspect(1.5), 1.5);
  });

  group('decodedAspectDiffers', () {
    test('is false within 2 percent', () {
      expect(decodedAspectDiffers(1.5, const Size(300, 200)), isFalse);
      expect(decodedAspectDiffers(1.5, const Size(306, 200)), isFalse);
    });

    test('is true for a rotated decode', () {
      expect(decodedAspectDiffers(1.5, const Size(200, 300)), isTrue);
    });
  });
}
