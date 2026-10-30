import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shows [placeholder] until the placeholder is actually painted, then mounts
/// [child] in its place.
///
/// For content too expensive to mount before a diver can see it, such as a
/// map. A lazy sliver lays out the rows in its cache band without painting
/// them, so a first paint is the moment this widget's row reaches the screen,
/// however it got there: a scroll, a window resize, or content above it
/// shrinking. A scroll listener would miss the last two and leave the
/// placeholder up on a page with nothing to scroll.
///
/// Content that is on screen from the start still loses one frame to the
/// placeholder, so the page around it paints without waiting for it.
///
/// [placeholder] must take the size [child] will, or the swap shifts the page.
class DeferUntilPainted extends StatefulWidget {
  const DeferUntilPainted({
    super.key,
    required this.placeholder,
    required this.child,
  });

  final Widget placeholder;
  final Widget child;

  @override
  State<DeferUntilPainted> createState() => _DeferUntilPaintedState();
}

class _DeferUntilPaintedState extends State<DeferUntilPainted> {
  bool _revealScheduled = false;
  bool _revealed = false;

  void _handlePainted() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    // Paint comes too late in the frame to dirty a widget.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) => _revealed
      ? widget.child
      : _PaintListener(onPainted: _handlePainted, child: widget.placeholder);
}

class _PaintListener extends SingleChildRenderObjectWidget {
  const _PaintListener({required this.onPainted, required super.child});

  final VoidCallback onPainted;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintListener(onPainted);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaintListener renderObject,
  ) {
    renderObject.onPainted = onPainted;
  }
}

class _RenderPaintListener extends RenderProxyBox {
  _RenderPaintListener(this.onPainted);

  VoidCallback onPainted;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPainted();
  }
}
