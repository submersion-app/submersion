import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:submersion/core/presentation/widgets/frame_budget_watch.dart';

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

  /// Forces the gradient/effect palette to a specific brightness instead of
  /// following the ambient theme. The startup splash renders bright (its
  /// throwaway MaterialApp defaults to a light theme), so screens that follow
  /// it — like the setup wizard — pass [Brightness.light] to stay as bright as
  /// the splash rather than stepping down to the dark-theme palette.
  final Brightness? brightness;

  /// Optional static backgrounds; ambient effects keep their original palette.
  final Gradient? backgroundGradient;
  final Gradient? backgroundHighlight;

  const OceanBackground({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.brightness,
    this.backgroundGradient,
    this.backgroundHighlight,
  });

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with WidgetsBindingObserver {
  /// Elapsed animation time; paused whenever the effects are frozen so they
  /// resume from where they stopped instead of jumping ahead. Built from
  /// [clock] so tests can drive it with fake time.
  final _stopwatch = clock.stopwatch();

  /// Animation position in cycles, read by the painter.
  final _animationValue = ValueNotifier<double>(0);

  /// Drives repaints at [_frameInterval]. A vsync ticker would request a frame
  /// on every display refresh (60 to 120 times a second) for bubbles that take
  /// seconds to rise, keeping an idle app busy (#3044).
  Timer? _frameTimer;

  AppLifecycleState? _lifecycleState;
  bool _tickersEnabled = true;
  bool _disableAnimations = false;

  /// Trips when the frames this animation drives keep running over budget,
  /// and the effects then hold still for good (#4177).
  final _frameBudget = FrameBudgetWatch();

  /// Whether [_onFrameTimings] is registered, which it is only while the
  /// effects animate.
  bool _watchingFrames = false;

  /// Seconds for one conceptual animation cycle (controls bubble rise speed).
  static const _cyclePeriod = 10.0;

  /// 30 frames per second.
  static const _frameInterval = Duration(microseconds: 33334);

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncAnimation();
  }

  /// Animates only while the effects can be seen and are wanted: the app is
  /// focused in the foreground (a null state means the platform has not
  /// reported one yet), the route is not covered, reduce motion is off, and
  /// the device has kept up with the frames so far.
  bool get _shouldAnimate =>
      (_lifecycleState == null ||
          _lifecycleState == AppLifecycleState.resumed) &&
      _tickersEnabled &&
      !_disableAnimations &&
      !_frameBudget.tripped;

  void _syncAnimation() {
    if (_shouldAnimate) {
      _watchFrames(true);
      if (_frameTimer != null) return;
      _stopwatch.start();
      _frameTimer = Timer.periodic(_frameInterval, (_) => _onFrame());
    } else {
      _watchFrames(false);
      _frameTimer?.cancel();
      _frameTimer = null;
      _stopwatch.stop();
    }
  }

  void _watchFrames(bool watch) {
    if (watch == _watchingFrames) return;
    _watchingFrames = watch;
    if (watch) {
      _frameBudget.restartCadence();
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (_frameBudget.record(timings)) {
      _syncAnimation();
    }
  }

  void _onFrame() {
    _animationValue.value =
        _stopwatch.elapsedMicroseconds / (_cyclePeriod * 1000000);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchFrames(false);
    _frameTimer?.cancel();
    _stopwatch.stop();
    _animationValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        (widget.brightness ?? Theme.of(context).brightness) == Brightness.dark;

    final gradientColors = isDark
        ? [
            // Abyss Blue: the deep-ocean dark palette.
            const Color(0xFF0B2540),
            const Color(0xFF08243A).withValues(alpha: 0.9),
            const Color(0xFF041220).withValues(alpha: 0.85),
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
        gradient:
            widget.backgroundGradient ??
            LinearGradient(
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
            if (widget.backgroundHighlight != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: widget.backgroundHighlight,
                  ),
                ),
              ),
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _animationValue,
                  builder: (context, t, _) {
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

  /// Each patch fills only its own square: the gradient is transparent
  /// beyond its radius, and a browser drawing without WebGL rasterises every
  /// picture on every frame, so a full-screen fill cost it two full-screen
  /// passes whenever anything animated (#4186).
  void _paintCaustics(Canvas canvas, Size size) {
    final t = animationValue * 2 * math.pi;
    final dx = math.sin(t) * 8;
    final dy = math.cos(t) * 4;

    // First caustic patch (upper-left area)
    final patch1 = Rect.fromCircle(
      center: Offset(size.width * 0.3 + dx, size.height * 0.4 + dy),
      radius: 80,
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: causticOpacity),
          Colors.transparent,
        ],
      ).createShader(patch1);
    canvas.drawRect(patch1, paint1);

    // Second caustic patch (lower-right area)
    final patch2 = Rect.fromCircle(
      center: Offset(size.width * 0.7 - dx, size.height * 0.6 - dy),
      radius: 60,
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: causticOpacity * 0.67),
          Colors.transparent,
        ],
      ).createShader(patch2);
    canvas.drawRect(patch2, paint2);
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
