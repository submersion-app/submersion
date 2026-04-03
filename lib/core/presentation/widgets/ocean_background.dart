import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Specification for a single animated bubble.
class BubbleSpec {
  final double x;
  final double size;
  final double speed;
  final double phase;

  const BubbleSpec({
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

/// 15 bubbles: 7 large, 5 medium, 3 small.
/// [speed] = controller cycles per bubble rise (higher = faster).
/// [phase] = initial offset in [0,1] to stagger start times.
const oceanBubbleSpecs = [
  // Large
  BubbleSpec(x: 0.08, size: 18, speed: 1.43, phase: 0.00),
  BubbleSpec(x: 0.22, size: 14, speed: 1.18, phase: 0.20),
  BubbleSpec(x: 0.38, size: 20, speed: 1.11, phase: 0.05),
  BubbleSpec(x: 0.52, size: 12, speed: 1.33, phase: 0.35),
  BubbleSpec(x: 0.65, size: 16, speed: 1.25, phase: 0.12),
  BubbleSpec(x: 0.78, size: 22, speed: 1.00, phase: 0.08),
  BubbleSpec(x: 0.90, size: 10, speed: 1.54, phase: 0.40),
  // Medium
  BubbleSpec(x: 0.15, size: 9, speed: 1.67, phase: 0.18),
  BubbleSpec(x: 0.45, size: 11, speed: 1.43, phase: 0.30),
  BubbleSpec(x: 0.58, size: 8, speed: 1.82, phase: 0.03),
  BubbleSpec(x: 0.72, size: 13, speed: 1.25, phase: 0.25),
  BubbleSpec(x: 0.85, size: 7, speed: 1.67, phase: 0.50),
  // Small
  BubbleSpec(x: 0.30, size: 5, speed: 2.00, phase: 0.10),
  BubbleSpec(x: 0.48, size: 6, speed: 1.82, phase: 0.45),
  BubbleSpec(x: 0.82, size: 4, speed: 2.22, phase: 0.22),
];

/// Animated ocean gradient background with caustic shimmer and rising bubbles.
///
/// Wraps a [child] widget with a cyan-teal gradient and ambient ocean effects.
/// Use [borderRadius] for rounded containers (e.g. cards).
class OceanBackground extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const OceanBackground({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _stopwatch = Stopwatch();

  /// Seconds for one conceptual animation cycle (controls bubble rise speed).
  static const _cyclePeriod = 10.0;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF00838F),
            const Color(0xFF00838F).withValues(alpha: 0.9),
            const Color(0xFF00796B).withValues(alpha: 0.85),
          ]
        : [
            const Color(0xFF00ACC1),
            const Color(0xFF00ACC1).withValues(alpha: 0.9),
            const Color(0xFF009688).withValues(alpha: 0.85),
          ];
    final bubbleColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.22);
    final causticOpacity = isDark ? 0.06 : 0.12;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: widget.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ticker,
                  builder: (context, _) {
                    final t =
                        _stopwatch.elapsedMilliseconds / (_cyclePeriod * 1000);
                    return CustomPaint(
                      painter: OceanEffectPainter(
                        animationValue: t,
                        bubbleColor: bubbleColor,
                        causticOpacity: causticOpacity,
                      ),
                    );
                  },
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// Paints caustic light shimmer and rising bubbles in a single paint pass.
class OceanEffectPainter extends CustomPainter {
  final double animationValue;
  final Color bubbleColor;
  final double causticOpacity;

  OceanEffectPainter({
    required this.animationValue,
    required this.bubbleColor,
    required this.causticOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintCaustics(canvas, size);
    _paintBubbles(canvas, size);
  }

  void _paintCaustics(Canvas canvas, Size size) {
    final t = animationValue * 2 * math.pi;
    final dx = math.sin(t) * 8;
    final dy = math.cos(t) * 4;
    final rect = Offset.zero & size;

    // First caustic patch (upper-left area)
    final center1 = Offset(size.width * 0.3 + dx, size.height * 0.4 + dy);
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: causticOpacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center1, radius: 80));
    canvas.drawRect(rect, paint1);

    // Second caustic patch (lower-right area)
    final center2 = Offset(size.width * 0.7 - dx, size.height * 0.6 - dy);
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: causticOpacity * 0.67),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center2, radius: 60));
    canvas.drawRect(rect, paint2);
  }

  void _paintBubbles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final highlightPaint = Paint()..style = PaintingStyle.fill;

    for (final spec in oceanBubbleSpecs) {
      final progress = (animationValue * spec.speed + spec.phase) % 1.0;

      // Y: rises from below bottom to above top
      final y = size.height * (1.2 - progress * 1.4);

      // X: base position + gentle sine wobble
      final wobble = math.sin(progress * 4 * math.pi) * 3;
      final x = spec.x * size.width + wobble;

      // Opacity: fade in quickly at bottom, sustain, fade out at top
      double opacity;
      if (progress < 0.05) {
        opacity = progress / 0.05;
      } else if (progress > 0.85) {
        opacity = (1.0 - progress) / 0.15;
      } else {
        opacity = 1.0;
      }
      opacity = opacity.clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final radius = spec.size / 2;

      // Main bubble
      paint.color = bubbleColor.withValues(alpha: bubbleColor.a * opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);

      // Subtle glass highlight on larger bubbles
      if (spec.size >= 10) {
        highlightPaint.color = Colors.white.withValues(alpha: 0.08 * opacity);
        canvas.drawCircle(
          Offset(x - radius * 0.25, y - radius * 0.25),
          radius * 0.4,
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(OceanEffectPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
