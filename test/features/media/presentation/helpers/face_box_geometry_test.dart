import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';

void main() {
  // A portrait photo shown in a landscape box: bars left and right.
  const image = Size(600, 800);
  const box = Size(1000, 400);

  test('containedImageRect letterboxes and centres the image', () {
    final rect = containedImageRect(image, box);
    expect(rect.height, 400);
    expect(rect.width, 300);
    expect(rect.left, 350);
    expect(rect.top, 0);
  });

  test('normalizedPoint maps a tap on the image to 0..1', () {
    final p = normalizedPoint(const Offset(500, 200), image, box)!;
    expect(p.dx, closeTo(0.5, 1e-9));
    expect(p.dy, closeTo(0.5, 1e-9));
  });

  test('normalizedPoint returns null for a tap in the bars', () {
    expect(normalizedPoint(const Offset(100, 200), image, box), isNull);
  });

  test('boxAround centres a screen-square box and keeps it inside', () {
    final b = boxAround(const Offset(0.5, 0.5), image: image, size: 0.2);
    expect(b.width, closeTo(0.2, 1e-9));
    // Square on screen: the height in image units scales by width/height.
    expect(b.height, closeTo(0.2 * 600 / 800, 1e-9));
    expect(b.center.x, closeTo(0.5, 1e-9));

    final edge = boxAround(const Offset(0.99, 0.01), image: image, size: 0.2);
    expect(edge.x + edge.width, lessThanOrEqualTo(1));
    expect(edge.y, greaterThanOrEqualTo(0));
  });

  test('boxRect places a normalised box over the contained image', () {
    const b = FaceBox(x: 0.5, y: 0.25, width: 0.5, height: 0.5);
    final rect = boxRect(b, image, box);
    expect(rect, const Rect.fromLTWH(350 + 150, 100, 150, 200));
  });

  test('formatMoment reads like a video clock', () {
    expect(formatMoment(const Duration(seconds: 42)), '0:42');
    expect(formatMoment(const Duration(minutes: 1, seconds: 58)), '1:58');
    expect(
      formatMoment(const Duration(hours: 1, minutes: 2, seconds: 5)),
      '1:02:05',
    );
  });

  group('faceImageSize', () {
    test('the decoded size wins: it is drawn upright', () {
      // Stored 4000 x 3000 from the container, EXIF-rotated portrait on
      // screen: the decoder's 3000 x 4000 is what the boxes sit on.
      expect(
        faceImageSize(width: 4000, height: 3000, decoded: const Size(300, 400)),
        const Size(300, 400),
      );
    });

    test('before decode the stored size stands in', () {
      expect(
        faceImageSize(width: 4000, height: 3000, decoded: null),
        const Size(4000, 3000),
      );
    });

    test('nothing known is null', () {
      expect(faceImageSize(width: null, height: 3000, decoded: null), isNull);
      expect(faceImageSize(width: 0, height: 0, decoded: null), isNull);
    });
  });
}
