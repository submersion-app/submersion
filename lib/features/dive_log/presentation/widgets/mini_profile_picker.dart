import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// A small read-only copy of the dive's profile to point at (#4109): a tap
/// or drag reports the second under the finger, and the chosen second is
/// drawn as a line with a dot on the depth curve.
class MiniProfilePicker extends StatelessWidget {
  const MiniProfilePicker({
    super.key,
    required this.profile,
    required this.selectedSeconds,
    required this.onPick,
    this.height = 90,
  });

  final List<DiveProfilePoint> profile;
  final int? selectedSeconds;
  final ValueChanged<int> onPick;
  final double height;

  int get _first => profile.first.timestamp;
  int get _last => profile.last.timestamp;

  int _secondsAt(double x, double width) {
    final span = _last - _first;
    if (span <= 0 || width <= 0) return _first;
    final fraction = (x / width).clamp(0.0, 1.0);
    return (_first + fraction * span).round();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onPick(_secondsAt(d.localPosition.dx, width)),
          onPanUpdate: (d) => onPick(_secondsAt(d.localPosition.dx, width)),
          child: SizedBox(
            height: height,
            width: width,
            child: CustomPaint(
              painter: MiniProfilePainter(
                profile: profile,
                selectedSeconds: selectedSeconds,
                curveColor: colors.primary,
                fillColor: colors.primary.withValues(alpha: 0.15),
                markerColor: ProfileMetricColors.annotation,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the depth curve (time left to right, depth downwards) and the
/// selected second's marker.
class MiniProfilePainter extends CustomPainter {
  const MiniProfilePainter({
    required this.profile,
    required this.selectedSeconds,
    required this.curveColor,
    required this.fillColor,
    required this.markerColor,
  });

  final List<DiveProfilePoint> profile;
  final int? selectedSeconds;
  final Color curveColor;
  final Color fillColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.isEmpty) return;
    final first = profile.first.timestamp;
    final span = math.max(1, profile.last.timestamp - first);
    var maxDepth = 0.0;
    for (final p in profile) {
      if (p.depth > maxDepth) maxDepth = p.depth;
    }
    if (maxDepth <= 0) maxDepth = 1;
    const top = 4.0;
    final plotHeight = size.height - top - 4;
    double x(int t) => (t - first) / span * size.width;
    double y(double d) => top + d / maxDepth * plotHeight;

    final path = Path()..moveTo(x(profile.first.timestamp), y(0));
    for (final p in profile) {
      path.lineTo(x(p.timestamp), y(p.depth));
    }
    path.lineTo(x(profile.last.timestamp), y(0));
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);

    final line = Path();
    for (var i = 0; i < profile.length; i++) {
      final p = profile[i];
      if (i == 0) {
        line.moveTo(x(p.timestamp), y(p.depth));
      } else {
        line.lineTo(x(p.timestamp), y(p.depth));
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final selected = selectedSeconds;
    if (selected == null) return;
    final sx = x(selected.clamp(first, profile.last.timestamp));
    canvas.drawLine(
      Offset(sx, 0),
      Offset(sx, size.height),
      Paint()
        ..color = markerColor
        ..strokeWidth = 1.5,
    );
    final depth = profileDepthAt(profile, selected);
    if (depth != null) {
      canvas.drawCircle(Offset(sx, y(depth)), 4, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(MiniProfilePainter old) =>
      old.profile != profile ||
      old.selectedSeconds != selectedSeconds ||
      old.curveColor != curveColor ||
      old.fillColor != fillColor ||
      old.markerColor != markerColor;
}
