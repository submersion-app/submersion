import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/presentation/helpers/white_point_sampler.dart';

/// A [w]x[h] straight-RGBA image: [inside] within the square centred on
/// (10, 10) with radius 4, [outside] everywhere else.
ByteData image(int w, int h, List<int> inside, List<int> outside) {
  final data = ByteData(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = (x - 10).abs() <= 4 && (y - 10).abs() <= 4 ? inside : outside;
      final o = (y * w + x) * 4;
      data
        ..setUint8(o, c[0])
        ..setUint8(o + 1, c[1])
        ..setUint8(o + 2, c[2])
        ..setUint8(o + 3, 255);
    }
  }
  return data;
}

/// Issue #3520: "Pick white" averages a small patch under the tap.
void main() {
  test('averages the patch around the tap', () {
    final w = averageWhiteAround(
      image(30, 30, [51, 102, 153], [255, 0, 0]),
      30,
      30,
      const Offset(10, 10),
    );
    expect(w, const WhitePoint(0.2, 0.4, 0.6));
  });

  test('a patch at the edge is clipped to the image', () {
    final w = averageWhiteAround(
      image(30, 30, [0, 0, 0], [51, 102, 153]),
      30,
      30,
      const Offset(29, 29),
    );
    expect(w, const WhitePoint(0.2, 0.4, 0.6));
  });

  test('outside the image is null', () {
    expect(
      averageWhiteAround(
        image(30, 30, [51, 102, 153], [51, 102, 153]),
        30,
        30,
        const Offset(40, 5),
      ),
      isNull,
    );
  });

  test('a nearly black patch is null', () {
    expect(
      averageWhiteAround(
        image(30, 30, [3, 3, 3], [200, 200, 200]),
        30,
        30,
        const Offset(10, 10),
      ),
      isNull,
    );
  });

  test('maps a tap in a contain-fit box onto the frame', () {
    // A 160x90 frame letterboxed in a 400x400 box: drawn 400x225, 87.5 down.
    expect(
      tapToFramePixel(
        const Offset(200, 200),
        boxSize: const Size(400, 400),
        frameSize: const Size(160, 90),
      ),
      const Offset(80, 45),
    );
    expect(
      tapToFramePixel(
        const Offset(200, 20),
        boxSize: const Size(400, 400),
        frameSize: const Size(160, 90),
      ),
      isNull,
    );
  });
}
