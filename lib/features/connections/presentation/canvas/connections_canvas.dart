import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_layout_controller.dart';

import 'connection_kind_colors.dart';
import 'connections_hit_tester.dart';
import 'connections_painter.dart';
import 'graph_viewport.dart';
import 'node_metrics.dart';

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
  });

  final ConnectionGraph graph;
  final ConnectionsLayoutController controller;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;
  final ValueChanged<NodeRef> onFocus;
  final String? semanticsLabel;

  @override
  State<ConnectionsCanvas> createState() => _ConnectionsCanvasState();
}

class _ConnectionsCanvasState extends State<ConnectionsCanvas> {
  GraphViewport _viewport = const GraphViewport();
  bool _fitted = false;
  Size _size = Size.zero;
  NodeRef? _hovered;
  Offset? _hoverPosition;
  NodeRef? _dragging;
  double _scaleBase = 1;
  double _panZoomBase = 1;
  Offset? _doubleTapPosition;
  final Map<NodeRef, ui.Image> _photos = {};

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
      _fitted = false;
      _decodePhotos();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFrame);
    for (final img in _photos.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _onFrame() {
    if (!mounted) return;
    setState(() {
      final frame = widget.controller.frame;
      if (!_fitted && _size != Size.zero && frame.positions.isNotEmpty) {
        _viewport = _viewport.fitted(frame.bounds, _size);
        _fitted = widget.controller.settled;
      }
    });
  }

  Future<void> _decodePhotos() async {
    final wanted = {
      for (final n in widget.graph.nodes)
        if (n.photo != null) n.ref: n.photo!,
    };
    for (final ref
        in _photos.keys.where((r) => !wanted.containsKey(r)).toList()) {
      _photos.remove(ref)?.dispose();
    }
    for (final entry in wanted.entries) {
      if (_photos.containsKey(entry.key)) continue;
      try {
        final img = await decodeImageFromList(entry.value);
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() => _photos[entry.key] = img);
      } catch (_) {
        // A corrupt photo falls back to initials.
      }
    }
  }

  double _radiusOf(NodeRef ref) {
    final node = widget.graph.nodeFor(ref);
    if (node == null) return NodeMetrics.minRadius;
    return NodeMetrics.radiusFor(node.diveCount, widget.graph.maxDiveCount) *
        _viewport.scale.clamp(0.5, 1.5);
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
      _viewport = _viewport
          .zoomedAt(factor, focal)
          .clampedTo(widget.controller.frame.bounds, _size);
    });
  }

  void _pan(Offset delta) {
    setState(() {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          if (!_fitted) {
            _viewport = _viewport.fitted(widget.controller.frame.bounds, size);
            _fitted = widget.controller.settled;
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
          photos: Map.unmodifiable(_photos),
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
                  left: (hoverPosition.dx + 12).clamp(0.0, size.width - 160),
                  top: (hoverPosition.dy + 12).clamp(0.0, size.height - 48),
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
