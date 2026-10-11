import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Paints a master list row's keyboard focus ring on the row's card (#3224).
///
/// Most rows are a card set inside a margin, a Padding or the Card's own,
/// that keeps neighbouring cards apart. A ring drawn around the row's bounds
/// sits out in that margin, wider than the card it marks. So the ring looks
/// down the row for its surface: the first [RenderPhysicalShape], which is
/// what a Card or a shaped Material paints with, reached through single-child
/// boxes alone. It traces that surface's own shape, so it also takes the
/// active theme's card radius.
///
/// A box with several children ends the search: a card found below one is
/// part of the row's contents (a chip in a dense row), not its surface. A row
/// with no shaped surface, like a plain ListTile or a full-width unshaped
/// Material, is ringed at its bounds.
class KeyboardListFocusRing extends SingleChildRenderObjectWidget {
  const KeyboardListFocusRing({
    super.key,
    required this.visible,
    required this.color,
    super.child,
  });

  /// Whether the ring is drawn. The widget stays in the tree either way, so
  /// showing the ring never rebuilds the row's contents (#3208).
  final bool visible;

  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderKeyboardListFocusRing(visible: visible, color: color);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderKeyboardListFocusRing renderObject,
  ) {
    renderObject
      ..visible = visible
      ..color = color;
  }
}

/// The render object of a [KeyboardListFocusRing].
class RenderKeyboardListFocusRing extends RenderProxyBox {
  RenderKeyboardListFocusRing({required bool visible, required Color color})
    : _visible = visible,
      _color = color;

  static const _width = 2.0;

  /// The shape of a row with no surface of its own.
  static const _boundsShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  bool _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    if (_visible) markNeedsPaint();
  }

  /// The whole row takes a click, margin included, as it did when the ring
  /// was a DecoratedBox, so a press anywhere on it still focuses the list.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_visible) return;
    final ring = _surfaceRing() ?? (Offset.zero & size, _boundsShape, null);
    final (rect, shape, textDirection) = ring;
    shape
        .copyWith(
          side: BorderSide(color: _color, width: _width),
        )
        .paint(
          context.canvas,
          rect.shift(offset),
          textDirection: textDirection,
        );
  }

  /// Where the row's surface sits, relative to this box, and its shape.
  (Rect, OutlinedBorder, TextDirection?)? _surfaceRing() {
    RenderObject? node = child;
    while (node is RenderObjectWithChildMixin &&
        node is! RenderPhysicalShape &&
        // An unshaped Material paints a full-width row with this; that row is
        // its own surface, so the ring stays at its bounds.
        node is! RenderPhysicalModel) {
      node = node.child;
    }
    if (node is! RenderPhysicalShape || !node.hasSize) return null;
    final clipper = node.clipper;
    if (clipper is! ShapeBorderClipper) return null;
    final shape = clipper.shape;
    if (shape is! OutlinedBorder) return null;
    final rect = MatrixUtils.transformRect(
      node.getTransformTo(this),
      Offset.zero & node.size,
    );
    return (rect, shape, clipper.textDirection);
  }
}
