import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Turns tickers and animation timers that honour [TickerMode] off below
/// it while [child] is scrolled wholly out of the enclosing scroll view.
///
/// Home's welcome banner animates its ocean on a 30 fps timer (issue
/// #5003). Once the banner has scrolled away under the pinned row of
/// lights it would keep an idle Home producing frames for nothing;
/// `OceanBackground` stops its timer whenever [TickerMode] is off.
class PauseWhenScrolledAway extends StatefulWidget {
  const PauseWhenScrolledAway({required this.child, super.key});

  final Widget child;

  @override
  State<PauseWhenScrolledAway> createState() => _PauseWhenScrolledAwayState();
}

class _PauseWhenScrolledAwayState extends State<PauseWhenScrolledAway> {
  ScrollPosition? _position;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;
    _position?.removeListener(_update);
    _position = position?..addListener(_update);
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    super.dispose();
  }

  /// Whether a measurement is already waiting for the next frame.
  bool _scheduled = false;

  /// The offset changes before the frame that lays it out, so measure once
  /// that frame is done, at most once a frame however often it scrolls.
  void _update() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _measure();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        scrollable is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        !scrollable.hasSize) {
      return;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: scrollable).dy;
    final visible = top + box.size.height > 0 && top < scrollable.size.height;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _visible, child: widget.child);
}
