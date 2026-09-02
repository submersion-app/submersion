import 'package:flutter/widgets.dart';

/// Maps the square crop viewport back into source-image pixel coordinates.
///
/// The crop is computed as GEOMETRY rather than by rasterizing the widget
/// through a `RepaintBoundary`. Rasterizing would bake in the device pixel
/// ratio, cap the output at whatever the viewport happened to render, and be
/// almost untestable. A rectangle is a pure value: the same gesture yields the
/// same stored image on a 1x desktop window and a 3x phone, and this function
/// unit-tests with no widget tree at all.
///
/// [transform] is `TransformationController.value` from the InteractiveViewer.
/// [viewport] is the square crop window in logical pixels, [childSize] is the
/// image as laid out inside the viewer, and [sourceSize] is the decoded
/// image's pixel dimensions.
Rect cropRectInSourcePixels({
  required Matrix4 transform,
  required Size viewport,
  required Size childSize,
  required Size sourceSize,
}) {
  // Undo the viewer's transform to find which part of the child the viewport
  // is currently showing.
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    Offset(viewport.width, viewport.height),
  );

  // Child (logical) pixels to source pixels. Each axis scales independently,
  // because a landscape image laid out at cover scale inside a square
  // viewport has different ratios horizontally and vertically.
  final scaleX = sourceSize.width / childSize.width;
  final scaleY = sourceSize.height / childSize.height;

  final rawLeft = topLeft.dx * scaleX;
  final rawTop = topLeft.dy * scaleY;
  final rawRight = bottomRight.dx * scaleX;
  final rawBottom = bottomRight.dy * scaleY;

  // Clamp into the image. minScale is set to the cover scale at the call
  // site, so a gap is not normally representable; this is a guard, not
  // routine control flow.
  final left = rawLeft.clamp(0.0, sourceSize.width);
  final top = rawTop.clamp(0.0, sourceSize.height);
  final right = rawRight.clamp(0.0, sourceSize.width);
  final bottom = rawBottom.clamp(0.0, sourceSize.height);

  // Never hand back a degenerate rect: the codec would crop to nothing.
  final width = (right - left).clamp(1.0, sourceSize.width);
  final height = (bottom - top).clamp(1.0, sourceSize.height);

  return Rect.fromLTWH(
    left.clamp(0.0, sourceSize.width - width),
    top.clamp(0.0, sourceSize.height - height),
    width,
    height,
  );
}
