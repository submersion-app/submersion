import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_geometry.dart';

void main() {
  test('identity transform over a square child selects the whole source', () {
    final rect = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.left, closeTo(0, 0.01));
    expect(rect.top, closeTo(0, 0.01));
    expect(rect.width, closeTo(1200, 0.01));
    expect(rect.height, closeTo(1200, 0.01));
  });

  test('a 2x zoom selects half the source in each axis', () {
    // InteractiveViewer's controller holds the scene-to-viewport transform,
    // so a 2x zoom means the viewport shows half as much of the child.
    final transform = Matrix4.identity()..scaleByDouble(2.0, 2.0, 1.0, 1.0);

    final rect = cropRectInSourcePixels(
      transform: transform,
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.width, closeTo(600, 0.01));
    expect(rect.height, closeTo(600, 0.01));
  });

  test('the result is independent of device pixel ratio', () {
    // The same gesture expressed at two viewport sizes must select the same
    // region of the SOURCE, which is what makes the stored image identical
    // on a 1x and a 3x screen.
    final small = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(200, 200),
      childSize: const Size(200, 200),
      sourceSize: const Size(1000, 1000),
    );
    final large = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(600, 600),
      childSize: const Size(600, 600),
      sourceSize: const Size(1000, 1000),
    );

    expect(small.width, closeTo(large.width, 0.01));
    expect(small.height, closeTo(large.height, 0.01));
    expect(small.left, closeTo(large.left, 0.01));
  });

  test('a pan beyond the image is clamped into bounds', () {
    final transform = Matrix4.identity()
      ..translateByDouble(500.0, 500.0, 0.0, 1.0);

    final rect = cropRectInSourcePixels(
      transform: transform,
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(1200));
    expect(rect.bottom, lessThanOrEqualTo(1200));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
  });

  test('a non-square child scales each axis independently', () {
    // A landscape source laid out at cover scale inside a square viewport.
    final rect = cropRectInSourcePixels(
      transform: Matrix4.identity(),
      viewport: const Size(300, 300),
      childSize: const Size(600, 300),
      sourceSize: const Size(1200, 600),
    );

    // The viewport covers the left half of the child, so the left half of
    // the source.
    expect(rect.width, closeTo(600, 0.01));
    expect(rect.height, closeTo(600, 0.01));
  });

  test('a degenerate transform never yields an empty rect', () {
    // Panning far past the bottom-right corner must still leave the codec a
    // croppable region rather than a zero-area rectangle.
    final transform = Matrix4.identity()
      ..translateByDouble(-5000.0, -5000.0, 0.0, 1.0);

    final rect = cropRectInSourcePixels(
      transform: transform,
      viewport: const Size(300, 300),
      childSize: const Size(300, 300),
      sourceSize: const Size(1200, 1200),
    );

    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
  });
}
