import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';

void main() {
  test('identity leaves a pixel unchanged', () {
    expect(ColorMatrix.identity.applyToPixel(10, 120, 200), (10, 120, 200));
    expect(ColorMatrix.identity.isIdentity, isTrue);
  });

  test('a near-identity matrix still counts as identity', () {
    final values = List<double>.of(ColorMatrix.identity.values);
    values[0] += 1e-9;
    expect(ColorMatrix(values).isIdentity, isTrue);
    expect(ColorMatrix.gains(1.01, 1, 1).isIdentity, isFalse);
  });

  test('then applies the left matrix first', () {
    final m = ColorMatrix.redFromGreen(0.5).then(ColorMatrix.gains(2, 1, 1));
    // (20 + 0.5 * 100) * 2 = 140
    expect(m.applyToPixel(20, 100, 0), (140, 100, 0));
  });

  test('then carries offsets through the second matrix', () {
    final m = ColorMatrix.brightness(1).then(ColorMatrix.gains(2, 1, 1));
    // (10 + 64) * 2 = 148
    expect(m.applyToPixel(10, 10, 10), (148, 74, 74));
  });

  test('lerp at 0 and 1 returns the ends', () {
    final g = ColorMatrix.gains(2, 1, 0.5);
    expect(ColorMatrix.lerp(ColorMatrix.identity, g, 0), ColorMatrix.identity);
    expect(ColorMatrix.lerp(ColorMatrix.identity, g, 1), g);
    expect(
      ColorMatrix.lerp(ColorMatrix.identity, g, 0.5),
      ColorMatrix.gains(1.5, 1, 0.75),
    );
  });

  test('warmth +1 raises red 25% and lowers blue 25%', () {
    expect(ColorMatrix.warmth(1).applyToPixel(100, 100, 100), (125, 100, 75));
  });

  test('tint +1 (magenta) lowers green 20%', () {
    expect(ColorMatrix.tint(1).applyToPixel(100, 100, 100), (100, 80, 100));
  });

  test('brightness +1 adds 64 to each channel', () {
    expect(ColorMatrix.brightness(1).applyToPixel(10, 10, 10), (74, 74, 74));
  });

  test('contrast +1 doubles the distance from 128', () {
    expect(ColorMatrix.contrast(1).applyToPixel(160, 96, 128), (192, 64, 128));
  });

  test('saturation -1 gives Rec. 709 grey', () {
    final (r, g, b) = ColorMatrix.saturation(-1).applyToPixel(255, 0, 0);
    expect(r, g);
    expect(g, b);
    expect(r, 54); // 0.2126 * 255 rounded
  });

  test('results clamp to 0..255', () {
    expect(ColorMatrix.gains(4, 1, 1).applyToPixel(200, 0, 0).$1, 255);
    expect(ColorMatrix.brightness(-1).applyToPixel(10, 10, 10), (0, 0, 0));
  });

  test('alpha passes through untouched', () {
    final m = ColorMatrix.warmth(1).then(ColorMatrix.contrast(0.5));
    expect(m.values.sublist(15), [0, 0, 0, 1, 0]);
  });
}
