import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Callback for when a region is selected.
typedef RegionSelectedCallback =
    void Function(LatLng southWest, LatLng northEast);

/// Widget for selecting a rectangular region on a map.
class RegionSelector extends StatefulWidget {
  final MapController mapController;
  final RegionSelectedCallback? onRegionSelected;
  final VoidCallback? onCancel;

  const RegionSelector({
    super.key,
    required this.mapController,
    this.onRegionSelected,
    this.onCancel,
  });

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  LatLng? _startPoint;
  LatLng? _endPoint;
  bool _isDragging = false;

  LatLng? get _southWest {
    if (_startPoint == null || _endPoint == null) return null;
    return LatLng(
      math.min(_startPoint!.latitude, _endPoint!.latitude),
      math.min(_startPoint!.longitude, _endPoint!.longitude),
    );
  }

  LatLng? get _northEast {
    if (_startPoint == null || _endPoint == null) return null;
    return LatLng(
      math.max(_startPoint!.latitude, _endPoint!.latitude),
      math.max(_startPoint!.longitude, _endPoint!.longitude),
    );
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final point = widget.mapController.camera.screenOffsetToLatLng(localPos);
    setState(() {
      _startPoint = point;
      _endPoint = point;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final point = widget.mapController.camera.screenOffsetToLatLng(localPos);
    setState(() {
      _endPoint = point;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  void _confirmSelection() {
    if (_southWest != null && _northEast != null) {
      widget.onRegionSelected?.call(_southWest!, _northEast!);
    }
  }

  void _clearSelection() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
    });
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _southWest != null && _northEast != null;

    return Stack(
      children: [
        // Gesture detector for drawing
        Positioned.fill(
          child: Semantics(
            label: 'Select region on map',
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            ),
          ),
        ),

        // Selection rectangle overlay
        if (hasSelection)
          Positioned.fill(
            child: CustomPaint(
              painter: _SelectionPainter(
                southWest: _southWest!,
                northEast: _northEast!,
                mapController: widget.mapController,
                color: colorScheme.primary,
              ),
            ),
          ),

        // Instructions overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.touch_app, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasSelection
                          ? 'Drag to adjust selection'
                          : 'Drag on the map to select a region',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action buttons
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearSelection,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: hasSelection ? _confirmSelection : null,
                  child: const Text('Select Region'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painter for the selection rectangle.
class _SelectionPainter extends CustomPainter {
  final LatLng southWest;
  final LatLng northEast;
  final MapController mapController;
  final Color color;

  _SelectionPainter({
    required this.southWest,
    required this.northEast,
    required this.mapController,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final camera = mapController.camera;

    final swPoint = camera.latLngToScreenOffset(southWest);
    final nePoint = camera.latLngToScreenOffset(northEast);

    final rect = Rect.fromPoints(
      Offset(swPoint.dx, nePoint.dy),
      Offset(nePoint.dx, swPoint.dy),
    );

    // Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, borderPaint);

    // Corner handles
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const handleSize = 12.0;

    canvas.drawCircle(rect.topLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.topRight, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomRight, handleSize / 2, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return southWest != oldDelegate.southWest ||
        northEast != oldDelegate.northEast;
  }
}
