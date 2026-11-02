import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// The plot insets fl_chart reserves, as the chart hands them to its
/// overlays.
typedef PlotInsets = ({double left, double top, double right, double bottom});

/// Where each annotation's dot sits in the layer's own coordinates: on the
/// depth curve at its time, or null for an annotation with no depth (a dive
/// without a profile) or outside the visible window.
List<Offset?> annotationDotCenters({
  required List<ProfileEvent> annotations,
  required Size size,
  required PlotInsets insets,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double visibleMinDepth,
  required double visibleMaxDepth,
  required double? Function(int seconds) depthAt,
}) {
  final plotW = (size.width - insets.left - insets.right).clamp(
    1.0,
    double.infinity,
  );
  final plotH = (size.height - insets.top - insets.bottom).clamp(
    1.0,
    double.infinity,
  );
  final rangeX = (visibleMaxSeconds - visibleMinSeconds).clamp(
    1e-9,
    double.infinity,
  );
  final rangeY = (visibleMaxDepth - visibleMinDepth).clamp(
    1e-9,
    double.infinity,
  );
  return [
    for (final a in annotations)
      if (a.timestamp < visibleMinSeconds || a.timestamp > visibleMaxSeconds)
        null
      else
        switch (depthAt(a.timestamp)) {
          null => null,
          final depth => Offset(
            insets.left + (a.timestamp - visibleMinSeconds) / rangeX * plotW,
            insets.top +
                ((depth - visibleMinDepth) / rangeY * plotH).clamp(0.0, plotH),
          ),
        },
  ];
}

/// The index of the dot nearest [local] within [radius] pixels, or null.
int? nearestAnnotationIndex(
  List<Offset?> centers,
  Offset local, {
  double radius = 20,
}) {
  int? best;
  var bestDistance = radius;
  for (var i = 0; i < centers.length; i++) {
    final c = centers[i];
    if (c == null) continue;
    final d = (c - local).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// The annotation dots on the dive profile (#4109): one filled dot on the
/// depth curve per annotation, a halo on the focused one, and a tap within
/// 20 px of a dot reports that annotation with the dot's global centre, for
/// the popup to anchor to. A translucent [Listener] over a painting that
/// ignores the pointer, so every pointer also reaches the layers below: the
/// chart's own gestures (pan, zoom, scrub) are never contested.
class AnnotationMarkerLayer extends StatefulWidget {
  const AnnotationMarkerLayer({
    super.key,
    required this.annotations,
    required this.insets,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.visibleMinDepth,
    required this.visibleMaxDepth,
    required this.depthAt,
    required this.onTap,
    this.interactive = true,
    this.focusedId,
    this.onReveal,
  });

  final List<ProfileEvent> annotations;
  final PlotInsets insets;
  final double visibleMinSeconds;
  final double visibleMaxSeconds;
  final double visibleMinDepth;
  final double visibleMaxDepth;

  /// Depth at a second, in the same unit as the visible depth window; null
  /// when the dive has no profile.
  final double? Function(int seconds) depthAt;
  final void Function(ProfileEvent annotation, Offset globalCenter) onTap;

  /// Off while the chart is in placement mode, so a tap near a dot places
  /// instead of opening.
  final bool interactive;

  /// The annotation drawn with a halo. When it changes to a new id, the
  /// layer reports that annotation through [onTap] once, after the frame,
  /// so the page can open its popup where the dot is. A dot outside the
  /// visible window goes through [onReveal] first.
  final String? focusedId;

  /// Brings a second outside the visible window into view. Returns whether
  /// the window moved; the layer then reports the focus from the new window.
  final bool Function(int seconds)? onReveal;

  @override
  State<AnnotationMarkerLayer> createState() => _AnnotationMarkerLayerState();
}

class _AnnotationMarkerLayerState extends State<AnnotationMarkerLayer> {
  Offset? _downLocal;
  int? _downPointer;

  /// The focused id waiting for the window [AnnotationMarkerLayer.onReveal]
  /// moved. A dot the pan could not reach stops here: the same pan again
  /// leaves the window where it is, and the report goes out anyway.
  String? _revealingId;

  List<Offset?> _centers(Size size) => annotationDotCenters(
    annotations: widget.annotations,
    size: size,
    insets: widget.insets,
    visibleMinSeconds: widget.visibleMinSeconds,
    visibleMaxSeconds: widget.visibleMaxSeconds,
    visibleMinDepth: widget.visibleMinDepth,
    visibleMaxDepth: widget.visibleMaxDepth,
    depthAt: widget.depthAt,
  );

  @override
  void didUpdateWidget(AnnotationMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focused = widget.focusedId;
    if (focused == null) {
      _revealingId = null;
    } else if (focused != oldWidget.focusedId || focused == _revealingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportFocused());
    }
  }

  /// The dot's depth is outside the zoomed window, so its dot is clamped to
  /// the plot's edge rather than sitting on the curve.
  bool _depthOffWindow(ProfileEvent annotation) {
    final depth = widget.depthAt(annotation.timestamp);
    return depth != null &&
        (depth < widget.visibleMinDepth || depth > widget.visibleMaxDepth);
  }

  void _reportFocused() {
    // Placement mode owns the next tap; a focus request waits like a tap
    // would (the dots are not interactive either).
    if (!mounted || !widget.interactive) return;
    final focused = widget.focusedId;
    final index = widget.annotations.indexWhere((a) => a.id == focused);
    if (index < 0) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final annotation = widget.annotations[index];
    final center = _centers(box.size)[index];
    if ((center == null || _depthOffWindow(annotation)) &&
        (widget.onReveal?.call(annotation.timestamp) ?? false)) {
      _revealingId = focused;
      return;
    }
    _revealingId = null;
    final local = center ?? Offset(box.size.width / 2, widget.insets.top);
    widget.onTap(annotation, box.localToGlobal(local));
  }

  void _onPointerDown(PointerDownEvent event) {
    // A right-click is the chart's, which answers it with its own menu.
    if (event.buttons & kPrimaryButton == 0) return;
    // A second finger makes it a gesture, not a tap on a dot.
    if (_downPointer != null) {
      _downLocal = null;
      return;
    }
    _downPointer = event.pointer;
    _downLocal = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event, Size size) {
    if (event.pointer != _downPointer) return;
    final down = _downLocal;
    _downLocal = null;
    _downPointer = null;
    if (!widget.interactive || down == null) return;
    if ((event.localPosition - down).distance > 12) return;
    final centers = _centers(size);
    final index = nearestAnnotationIndex(centers, event.localPosition);
    if (index == null) return;
    final box = context.findRenderObject() as RenderBox;
    widget.onTap(widget.annotations[index], box.localToGlobal(centers[index]!));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerCancel: (e) {
            if (e.pointer == _downPointer) {
              _downLocal = null;
              _downPointer = null;
            }
          },
          onPointerUp: (e) => _onPointerUp(e, size),
          // A CustomPaint counts as hit everywhere, which would stop the
          // pointer here however translucent the Listener is.
          child: IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _AnnotationDotsPainter(
                centers: _centers(size),
                focusedIndex: widget.annotations.indexWhere(
                  (a) => a.id == widget.focusedId,
                ),
                color: ProfileMetricColors.annotation,
                outline: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnnotationDotsPainter extends CustomPainter {
  const _AnnotationDotsPainter({
    required this.centers,
    required this.focusedIndex,
    required this.color,
    required this.outline,
  });

  final List<Offset?> centers;
  final int focusedIndex;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final halo = Paint()..color = color.withValues(alpha: 0.3);
    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      if (c == null) continue;
      if (i == focusedIndex) canvas.drawCircle(c, 9, halo);
      canvas.drawCircle(c, 5, fill);
      canvas.drawCircle(c, 5, ring);
    }
  }

  @override
  bool shouldRepaint(_AnnotationDotsPainter old) =>
      old.focusedIndex != focusedIndex ||
      old.color != color ||
      old.outline != outline ||
      !_sameCenters(old.centers, centers);

  static bool _sameCenters(List<Offset?> a, List<Offset?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
