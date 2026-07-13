import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/services/profile_sparkline.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Tiny depth-vs-time curve for a dive row. Renders nothing when the dive
/// has no usable profile.
///
/// Loads the dive's primary-source profile lazily via [diveProfileProvider]
/// (per visible row) rather than reading `Dive.profile`: the trip dive query
/// hydrates profiles unfiltered (all sources, including demoted rows), so a
/// multi-source dive would otherwise render an interleaved, inaccurate curve.
/// Lazy per-row loading also avoids materializing every dive's profile up front.
class DiveSparkline extends ConsumerWidget {
  final String diveId;
  final double width;
  final double height;

  const DiveSparkline({
    super.key,
    required this.diveId,
    this.width = 60,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(diveProfileProvider(diveId)).value ?? const [];
    final points = sparklinePoints(profile);
    if (points.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _SparklinePainter(
            points: points,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<({double t, double depth})> points;
  final Color color;

  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points[i].t * size.width;
      final y = points[i].depth * (size.height - 2) + 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
