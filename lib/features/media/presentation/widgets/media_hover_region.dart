import 'package:flutter/widgets.dart';

/// Reports whether a mouse pointer is over [child], including the case a
/// plain [MouseRegion] leaves out: Flutter does not call `onExit` for a
/// region that is removed from the tree while the pointer is over it (an
/// unlinked thumbnail, a rebuilt grid), so a listener that set something on
/// enter would never be told to clear it. This region reports that leave
/// itself.
///
/// Only a mouse or trackpad pointer hovers; a touch reports nothing.
class MediaHoverRegion extends StatefulWidget {
  const MediaHoverRegion({
    super.key,
    required this.onHoverChanged,
    required this.child,
  });

  /// Called with true when a mouse pointer enters and false when it leaves,
  /// and with false once more, after the current frame, if the region is
  /// removed while hovered.
  ///
  /// That last call is deferred because it is made from `dispose`, and the
  /// listener may write a provider, which is not allowed while the tree is
  /// being built or torn down. It can therefore arrive after this region's
  /// owner has gone too, and after another region has reported an enter.
  final ValueChanged<bool> onHoverChanged;

  final Widget child;

  @override
  State<MediaHoverRegion> createState() => _MediaHoverRegionState();
}

class _MediaHoverRegionState extends State<MediaHoverRegion> {
  bool _hovered = false;

  void _set(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    widget.onHoverChanged(hovered);
  }

  @override
  void dispose() {
    if (_hovered) {
      final onHoverChanged = widget.onHoverChanged;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onHoverChanged(false),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _set(true),
    onExit: (_) => _set(false),
    child: widget.child,
  );
}
