import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

import 'package:submersion/features/connections/presentation/canvas/camera_tween.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_hit_tester.dart';
import 'package:submersion/features/connections/presentation/canvas/connections_painter.dart';
import 'package:submersion/features/connections/presentation/canvas/decoded_photo_cache.dart';
import 'package:submersion/features/connections/presentation/canvas/node_photo_decoder.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';
import 'package:submersion/features/connections/presentation/canvas/node_metrics.dart';

/// The interactive graph surface. Owns the viewport, decoded photos, hover
/// and drag state; the layout lives in [controller] and the selection in the
/// caller.
class ConnectionsCanvas extends StatefulWidget {
  const ConnectionsCanvas({
    super.key,
    required this.graph,
    required this.controller,
    required this.colors,
    required this.onSelect,
    required this.onFocus,
    this.selection,
    this.semanticsLabel,
    this.animate = false,
  });

  final ConnectionGraph graph;
  final ConnectionsLayoutController controller;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  final String? semanticsLabel;

  /// Glide the camera to the new fit when the graph changes (a refocus).
  final bool animate;

  @override
  State<ConnectionsCanvas> createState() => _ConnectionsCanvasState();
}

class _ConnectionsCanvasState extends State<ConnectionsCanvas>
    with SingleTickerProviderStateMixin {
  GraphViewport _viewport = const GraphViewport();

  /// The camera follows the layout until the diver moves it.
  bool _autoFit = true;

  /// False until the first fit, which snaps; later fits ease.
  bool _everFitted = false;
  Size _size = Size.zero;
  NodeRef? _hovered;
  Offset? _hoverPosition;
  NodeRef? _dragging;
  double _scaleBase = 1;
  double _panZoomBase = 1;
  Offset? _doubleTapPosition;
  late final _photos = DecodedPhotoCache<ui.Image>(
    dispose: (img) => img.dispose(),
  );
  final Map<NodeRef, TextPainter> _labelCache = {};
  final Map<NodeRef, TextPainter> _dimLabelCache = {};
  final Map<(NodeRef, int), TextPainter> _initialsCache = {};
  TextStyle? _cachedLabelStyle;

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: kRefocusDuration,
  )..addListener(_onGlide);
  GraphViewport? _glideFrom;

  void _onGlide() {
    final from = _glideFrom;
    if (from == null || _size == Size.zero) return;
    setState(() {
      _viewport = CameraTween(
        from,
        _fitTarget(_size),
        _size,
      ).at(kRefocusCurve.transform(_glide.value));
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFrame);
    _decodePhotos();
  }

  @override
  void didUpdateWidget(ConnectionsCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onFrame);
      widget.controller.addListener(_onFrame);
    }
    if (old.graph != widget.graph) {
      _autoFit = true;
      if (widget.animate &&
          _everFitted &&
          !MediaQuery.disableAnimationsOf(context)) {
        _glideFrom = _viewport;
        _glide.forward(from: 0);
      }
      _clearTextCaches();
      _decodePhotos();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFrame);
    _glide.dispose();
    _photos.disposeAll();
    _clearTextCaches();
    super.dispose();
  }

  void _onFrame() {
    if (!mounted) return;
    setState(() {
      final frame = widget.controller.frame;
      // While a refocus glide runs it owns the camera.
      if (_glide.isAnimating) return;
      if (!_autoFit || _size == Size.zero || frame.positions.isEmpty) return;
      final target = _fitTarget(_size);
      if (!_everFitted || widget.controller.settled) {
        _viewport = target;
        _everFitted = true;
        if (widget.controller.settled) _autoFit = false;
        return;
      }
      _viewport = CameraTween(_viewport, target, _size).at(0.25);
    });
  }

  Future<void> _decodePhotos() {
    final wanted = {
      for (final n in widget.graph.nodes)
        if (n.photo != null) n.ref: n.photo!,
    };
    return _photos.sync(
      wanted,
      decodeNodePhoto,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _clearTextCaches() {
    _labelCache.clear();
    _dimLabelCache.clear();
    _initialsCache.clear();
  }

  double _radiusOf(NodeRef ref) {
    final node = widget.graph.nodeFor(ref);
    if (node == null) return NodeMetrics.minRadius;
    return NodeMetrics.radiusFor(node.diveCount, widget.graph.maxDiveCount) *
        _viewport.scale.clamp(0.5, 1.5);
  }

  /// Where the camera should be for the current frame, leaving room for the
  /// largest node and a full label on every side.
  GraphViewport _fitTarget(Size size) {
    const r = NodeMetrics.maxRadius * 1.5;
    final labelHeight = (_cachedLabelStyle?.fontSize ?? 11) * 1.5;
    return _viewport.fittedWithOverhang(
      widget.controller.frame.bounds,
      size,
      left: math.max(r, 70),
      top: r,
      right: math.max(r, 70),
      bottom: r + 2 + labelHeight,
    );
  }

  NodeRef? _nodeAt(Offset p) => ConnectionsHitTester.hitNode(
    p,
    frame: widget.controller.frame,
    viewport: _viewport,
    radiusOf: _radiusOf,
  );

  void _tap(Offset p) {
    final node = _nodeAt(p);
    if (node != null) {
      widget.onSelect(NodeSelection(node));
      return;
    }
    final edge = ConnectionsHitTester.hitEdge(
      p,
      frame: widget.controller.frame,
      viewport: _viewport,
      edges: widget.graph.edges,
    );
    widget.onSelect(
      edge == null ? null : EdgeSelection(edge.source, edge.target),
    );
  }

  void _zoomAt(double factor, Offset focal) {
    setState(() {
      _autoFit = false;
      _glide.stop();
      _viewport = _viewport
          .zoomedAt(factor, focal)
          .clampedTo(widget.controller.frame.bounds, _size);
    });
  }

  void _pan(Offset delta) {
    setState(() {
      _autoFit = false;
      _glide.stop();
      _viewport = _viewport
          .panned(delta)
          .clampedTo(widget.controller.frame.bounds, _size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    if (labelStyle != _cachedLabelStyle) {
      _clearTextCaches();
      _cachedLabelStyle = labelStyle;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          if (_autoFit && widget.controller.frame.positions.isNotEmpty) {
            _viewport = _fitTarget(size);
            _everFitted = true;
            if (widget.controller.settled) _autoFit = false;
          }
        }
        final painter = ConnectionsPainter(
          graph: widget.graph,
          frame: widget.controller.frame,
          viewport: _viewport,
          colors: widget.colors,
          labelStyle: labelStyle,
          selection: widget.selection,
          hovered: _hovered,
          photos: _photos.images,
          labelCache: _labelCache,
          dimLabelCache: _dimLabelCache,
          initialsCache: _initialsCache,
          haloColor: theme.colorScheme.surface,
        );
        final gestures = RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _TouchScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _TouchScaleGestureRecognizer
                >(
                  () => _TouchScaleGestureRecognizer(
                    supportedDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.unknown,
                    },
                  ),
                  (r) => r
                    ..onStart = (_) {
                      _scaleBase = _viewport.scale;
                    }
                    ..onUpdate = (d) {
                      if (_dragging != null) return;
                      if (d.pointerCount < 2) {
                        _pan(d.focalPointDelta);
                      } else {
                        final target = (_scaleBase * d.scale).clamp(
                          GraphViewport.minScale,
                          GraphViewport.maxScale,
                        );
                        _zoomAt(target / _viewport.scale, d.localFocalPoint);
                        _pan(d.focalPointDelta);
                      }
                    },
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (r) => r.onTapUp = (d) => _tap(d.localPosition),
                ),
            DoubleTapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  DoubleTapGestureRecognizer
                >(
                  () => DoubleTapGestureRecognizer(),
                  (r) => r
                    ..onDoubleTapDown = (d) {
                      _doubleTapPosition = d.localPosition;
                    }
                    ..onDoubleTap = () {
                      final p = _doubleTapPosition;
                      if (p == null) return;
                      final node = _nodeAt(p);
                      if (node != null) widget.onFocus(node);
                    },
                ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(),
                  (r) => r
                    ..onLongPressStart = (d) {
                      _autoFit = false;
                      _glide.stop();
                      _dragging = _nodeAt(d.localPosition);
                      if (_dragging != null) {
                        widget.onSelect(NodeSelection(_dragging!));
                      }
                    }
                    ..onLongPressMoveUpdate = (d) {
                      final node = _dragging;
                      if (node == null) return;
                      widget.controller.moveNode(
                        node,
                        _viewport.toGraph(d.localPosition),
                      );
                    }
                    ..onLongPressEnd = (_) {
                      _dragging = null;
                    }
                    ..onLongPressCancel = () {
                      _dragging = null;
                    },
                ),
          },
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('connections-canvas-paint'),
              painter: painter,
              size: size,
            ),
          ),
        );
        final interactive = Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomAt(
                signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                signal.localPosition,
              );
            }
          },
          onPointerPanZoomStart: (_) => _panZoomBase = _viewport.scale,
          onPointerPanZoomUpdate: (e) {
            final target = (_panZoomBase * e.scale).clamp(
              GraphViewport.minScale,
              GraphViewport.maxScale,
            );
            _zoomAt(target / _viewport.scale, e.localPosition);
            _pan(e.panDelta);
          },
          child: MouseRegion(
            onHover: (e) {
              final node = _nodeAt(e.localPosition);
              if (node != _hovered || node != null) {
                setState(() {
                  _hovered = node;
                  _hoverPosition = node == null ? null : e.localPosition;
                });
              }
            },
            onExit: (_) => setState(() {
              _hovered = null;
              _hoverPosition = null;
            }),
            child: gestures,
          ),
        );
        final hovered = _hovered;
        final hoverPosition = _hoverPosition;
        return Semantics(
          label: widget.semanticsLabel,
          container: true,
          child: Stack(
            children: [
              Positioned.fill(child: interactive),
              if (hovered != null && hoverPosition != null)
                Positioned(
                  left: (hoverPosition.dx + 12).clamp(
                    0.0,
                    math.max(0.0, size.width - 160),
                  ),
                  top: (hoverPosition.dy + 12).clamp(
                    0.0,
                    math.max(0.0, size.height - 48),
                  ),
                  child: IgnorePointer(
                    child: _HoverTooltip(
                      label: widget.graph.nodeFor(hovered)?.label ?? '',
                      count: widget.graph.nodeFor(hovered)?.diveCount ?? 0,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Refuses trackpad pan-zoom so the Listener above handles it once. Same
/// arrangement as the 3D viewport (dive_3d_interactive_viewport.dart).
class _TouchScaleGestureRecognizer extends ScaleGestureRecognizer {
  _TouchScaleGestureRecognizer({super.supportedDevices});

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

class _HoverTooltip extends StatelessWidget {
  const _HoverTooltip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '$label ($count)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}
