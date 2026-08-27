import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';

void main() {
  test('mercator normalization anchors', () {
    expect(mercatorX(-180), 0.0);
    expect(mercatorX(0), 0.5);
    expect(mercatorX(180), 1.0);
    expect(mercatorY(0), closeTo(0.5, 1e-12));
    // The mercator world edge (~85.0511 N) maps to y = 0.
    expect(mercatorY(85.05112878), closeTo(0.0, 1e-9));
  });

  test('slippyTileOf matches the standard formula', () {
    // At z=1 the world is 2x2; (0,0) sits in the SE quadrant tile (1,1).
    expect(slippyTileOf(0, 0, 1), (x: 1, y: 1));
    // Bonaire (12.15 N, -68.3 E) at z=14: x = floor((111.7/360)*16384)
    // = floor(0.310278 * 16384) = 5083; y from mercatorY(12.15) = 0.465995
    // -> floor(0.465995 * 16384) = 7634.
    expect(slippyTileOf(12.15, -68.3, 14), (x: 5083, y: 7634));
  });

  test('poles and out-of-range coordinates clamp instead of diverging', () {
    // Web Mercator is undefined at the poles: the raw formula returns a
    // non-finite y there, and floor() on a non-finite double throws.
    expect(mercatorY(90), closeTo(0.0, 1e-9));
    expect(mercatorY(-90), closeTo(1.0, 1e-9));
    // Tile indices stay inside 0..n-1 even at the world's edges.
    expect(slippyTileOf(90, 0, 4), (x: 8, y: 0));
    expect(slippyTileOf(-90, 0, 4), (x: 8, y: 15));
    expect(slippyTileOf(0, 180, 4), (x: 15, y: 8));
  });

  test('imageryZoomFor targets a handful of tiles and clamps', () {
    // 8 km box near the equator is ~0.0719 degrees of longitude:
    // z = round(log2(4 * 360 / 0.0719)) = round(14.29) = 14.
    expect(imageryZoomFor(lonSpanDeg: 0.0719, maxZoom: 18), 14);
    // A huge span clamps to the floor; a tiny one to the style's ceiling.
    expect(imageryZoomFor(lonSpanDeg: 300, maxZoom: 18), 10);
    expect(imageryZoomFor(lonSpanDeg: 0.00001, maxZoom: 18), 18);
  });
}
