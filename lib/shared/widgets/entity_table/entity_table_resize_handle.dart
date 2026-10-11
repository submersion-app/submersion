import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Widest a column can be dragged.
const double kEntityTableMaxColumnWidth = 600.0;

/// The drag handle on a header's trailing edge (#2984).
///
/// Width is computed from where the drag STARTED, not added up from deltas,
/// so the edge stays under the pointer after the width hits [minWidth] and
/// the pointer comes back. [onResize] gets each live width; [onResizeEnd]
/// fires once when the drag ends or is cancelled, which is when the table
/// saves.
class EntityTableResizeHandle extends StatefulWidget {
  const EntityTableResizeHandle({
    super.key,
    required this.width,
    required this.minWidth,
    required this.handleWidth,
    required this.color,
    required this.onResize,
    this.onResizeEnd,
  });

  final double width;
  final double minWidth;
  final double handleWidth;
  final Color color;
  final ValueChanged<double> onResize;
  final VoidCallback? onResizeEnd;

  @override
  State<EntityTableResizeHandle> createState() =>
      _EntityTableResizeHandleState();
}

class _EntityTableResizeHandleState extends State<EntityTableResizeHandle> {
  double? _startWidth;
  double _startX = 0;
  double? _last;

  void _end() {
    if (_startWidth == null) return;
    _startWidth = null;
    _last = null;
    widget.onResizeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Measured from pointer-down, so the touch slop is not lost.
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: (d) {
        _startWidth = widget.width;
        _startX = d.globalPosition.dx;
      },
      onHorizontalDragUpdate: (d) {
        final start = _startWidth;
        if (start == null) return;
        // Columns run right to left in an RTL locale, so dragging left
        // widens them there.
        final sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
        final next = (start + sign * (d.globalPosition.dx - _startX))
            .clamp(widget.minWidth, kEntityTableMaxColumnWidth)
            .toDouble();
        if (next == _last) return;
        _last = next;
        widget.onResize(next);
      },
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: widget.handleWidth,
          child: Center(child: Container(width: 1, color: widget.color)),
        ),
      ),
    );
  }
}
