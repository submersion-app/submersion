import 'package:flutter/widgets.dart';

/// Height of the band along the bottom of the header card that the map never
/// reaches.
const double kHeaderMapBottomInset = 16;

/// A decorative map that fades into [fadeColor] toward the bottom of the dive
/// detail header card, so the header text stays readable over it.
///
/// [child] is the map. It is clipped [kHeaderMapBottomInset] short of the
/// bottom edge, and the fade is fully opaque over that band.
///
/// The map must never reach the card's bottom edge. An opaque overlay whose
/// edge merely coincides with the map's edge does not hide it once the card
/// sits on a sub-pixel offset, as it does on every frame of an overscroll
/// bounce: the partly covered bottom pixel row blends in map pixels that the
/// overlay only partly covers, which flickered as a bright line along the
/// card's bottom edge. Ending the map inside the opaque band keeps its edge
/// under solid overlay instead.
class HeaderMapBackdrop extends StatelessWidget {
  const HeaderMapBackdrop({
    super.key,
    required this.fadeColor,
    required this.child,
  });

  /// The color the map fades into; the header card's background.
  final Color fadeColor;

  /// The map drawn behind the fade.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // Where the fade turns fully opaque, as a fraction of the height: the
        // top of the band the map is clipped out of. The fade keeps its shape
        // over the map above that point.
        final opaqueFrom = height > kHeaderMapBottomInset
            ? (height - kHeaderMapBottomInset) / height
            : 0.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              clipper: const _BottomInsetClipper(kHeaderMapBottomInset),
              child: child,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [
                    0.0,
                    0.3 * opaqueFrom,
                    0.7 * opaqueFrom,
                    opaqueFrom,
                    1.0,
                  ],
                  colors: [
                    fadeColor.withValues(alpha: 0.3),
                    fadeColor.withValues(alpha: 0.6),
                    fadeColor.withValues(alpha: 0.85),
                    fadeColor,
                    fadeColor,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Clips [inset] off the bottom of its child, leaving nothing when the child
/// is shorter than that.
class _BottomInsetClipper extends CustomClipper<Rect> {
  const _BottomInsetClipper(this.inset);

  final double inset;

  @override
  Rect getClip(Size size) {
    final bottom = size.height > inset ? size.height - inset : 0.0;
    return Rect.fromLTRB(0, 0, size.width, bottom);
  }

  @override
  bool shouldReclip(_BottomInsetClipper oldClipper) =>
      oldClipper.inset != inset;
}
