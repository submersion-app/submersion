import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';

/// Axis gutters `DiveTrendChart` reserves around its plot. A gesture's focal
/// point is taken against the inner plot rect, not the whole widget.
const trendChartPlotInsets = (left: 50.0, right: 0.0, top: 0.0, bottom: 30.0);

/// Every pointer input a `DiveTrendChart` understands: mouse drag and wheel,
/// touch drag and pinch, and trackpad pan-zoom.
///
/// Owns gesture bookkeeping only. The viewport belongs to the chart, which
/// hands the current one in and takes each new one back through
/// [onViewportChanged], so the zoom buttons and the overview strip edit the
/// same value.
class TrendChartInputLayer extends StatefulWidget {
  const TrendChartInputLayer({
    super.key,
    required this.box,
    required this.viewport,
    required this.onViewportChanged,
    required this.child,
  });

  final Size box;
  final ChartViewport viewport;
  final ValueChanged<ChartViewport> onViewportChanged;
  final Widget child;

  @override
  State<TrendChartInputLayer> createState() => _TrendChartInputLayerState();
}

class _TrendChartInputLayerState extends State<TrendChartInputLayer> {
  /// The latest viewport this layer emitted or was given. Several pointer
  /// events can land in one frame, before the chart rebuilds with the value
  /// emitted for the first, so deltas must build on this rather than on
  /// `widget.viewport`.
  late ChartViewport _current = widget.viewport;

  ChartViewport _gestureStartViewport = ChartViewport.reset;
  PointerDeviceKind _activePointerKind = PointerDeviceKind.mouse;
  int _activePointerCount = 0;
  Offset? _lastPointerLocal;
  bool _touchDragClaimed = false;
  final Map<int, Offset> _touchPositions = {};
  List<int> _pinchPointers = const [];
  double _pinchStartDistance = 1;
  Offset _pinchStartFocal = Offset.zero;

  @override
  void didUpdateWidget(TrendChartInputLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.viewport;
  }

  void _emit(ChartViewport next) {
    _current = next;
    widget.onViewportChanged(next);
  }

  double _focalX(Offset localPos) => chartFocalFraction(
    localPos,
    widget.box,
    left: trendChartPlotInsets.left,
    right: trendChartPlotInsets.right,
    top: trendChartPlotInsets.top,
    bottom: trendChartPlotInsets.bottom,
  ).fx;

  double _plotWidth() =>
      (widget.box.width -
              trendChartPlotInsets.left -
              trendChartPlotInsets.right)
          .clamp(1.0, double.infinity);

  void _zoomAt(Offset localPosition, double zoomDelta) {
    if (zoomDelta == 0) return;
    _activePointerKind = PointerDeviceKind.trackpad;
    _emit(
      _current.zoomedAt(
        _focalX(localPosition),
        0,
        math.pow(2, zoomDelta).toDouble(),
      ),
    );
  }

  void _beginPinch() {
    _pinchPointers = _touchPositions.keys.take(2).toList(growable: false);
    final p0 = _touchPositions[_pinchPointers[0]]!;
    final p1 = _touchPositions[_pinchPointers[1]]!;
    _pinchStartDistance = (p0 - p1).distance.clamp(1.0, double.infinity);
    _pinchStartFocal = (p0 + p1) / 2;
    _gestureStartViewport = _current;
  }

  void _updatePinch() {
    if (_pinchPointers.length < 2) return;
    final p0 = _touchPositions[_pinchPointers[0]];
    final p1 = _touchPositions[_pinchPointers[1]];
    if (p0 == null || p1 == null) return;
    final scale =
        (p0 - p1).distance.clamp(1.0, double.infinity) / _pinchStartDistance;
    var vp = _gestureStartViewport.zoomedAt(
      _focalX(_pinchStartFocal),
      0,
      scale,
    );
    final panPx = (p0 + p1) / 2 - _pinchStartFocal;
    vp = vp.pannedBy(-panPx.dx / _plotWidth() / vp.zoom, 0);
    _emit(vp);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        TrackpadZoomGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TrackpadZoomGestureRecognizer>(
              () => TrackpadZoomGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onZoom = _zoomAt,
            ),
      },
      child: Listener(
        onPointerDown: (event) {
          _activePointerCount++;
          _activePointerKind = event.kind;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
            if (_touchPositions.length == 2) _beginPinch();
          }
        },
        onPointerMove: (event) {
          final prev = _lastPointerLocal;
          _lastPointerLocal = event.localPosition;
          if (event.kind == PointerDeviceKind.touch) {
            _touchPositions[event.pointer] = event.localPosition;
          }
          if (prev == null) return;
          final intent = chartDragIntent(
            kind: _activePointerKind,
            pointerCount: _activePointerCount,
            isZoomed: _current.isZoomed,
          );
          if (intent == ChartDragIntent.zoomPan &&
              _activePointerKind == PointerDeviceKind.touch) {
            _updatePinch();
            return;
          }
          if (intent != ChartDragIntent.pan) return;
          // A touch drag only pans once the claim recognizer has won the
          // arena, so a scrub is never fought by a pan.
          if (_activePointerKind == PointerDeviceKind.touch &&
              !_touchDragClaimed) {
            return;
          }
          final d = event.localPosition - prev;
          _emit(_current.pannedBy(-d.dx / _plotWidth() / _current.zoom, 0));
        },
        onPointerUp: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          if (_pinchPointers.contains(event.pointer)) {
            _touchPositions.length >= 2
                ? _beginPinch()
                : _pinchPointers = const [];
          }
        },
        onPointerCancel: (event) {
          if (_activePointerCount > 0) _activePointerCount--;
          _lastPointerLocal = null;
          _touchPositions.remove(event.pointer);
          _pinchPointers = const [];
        },
        // Trackpad pan-zoom is claimed by the recognizer above so it does
        // not also scroll the enclosing page.
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          _activePointerKind = PointerDeviceKind.mouse;
          final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
          _emit(_current.zoomedAt(_focalX(event.localPosition), 0, factor));
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: {
                  ChartTouchClaimRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        ChartTouchClaimRecognizer
                      >(
                        () => ChartTouchClaimRecognizer(
                          isZoomed: () => _current.isZoomed,
                          debugOwner: this,
                        ),
                        (recognizer) {
                          recognizer.onClaimed = () {
                            _touchDragClaimed = true;
                          };
                          recognizer.onReleased = () {
                            _touchDragClaimed = false;
                          };
                        },
                      ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
