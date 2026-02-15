import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Specification for a single animated bubble.
class _BubbleSpec {
  final double x;
  final double size;
  final double speed;
  final double phase;

  const _BubbleSpec({
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

/// 15 bubbles: 7 large, 5 medium, 3 small.
/// [speed] = controller cycles per bubble rise (higher = faster).
/// [phase] = initial offset in [0,1] to stagger start times.
const _bubbleSpecs = [
  // Large
  _BubbleSpec(x: 0.08, size: 18, speed: 1.43, phase: 0.00),
  _BubbleSpec(x: 0.22, size: 14, speed: 1.18, phase: 0.20),
  _BubbleSpec(x: 0.38, size: 20, speed: 1.11, phase: 0.05),
  _BubbleSpec(x: 0.52, size: 12, speed: 1.33, phase: 0.35),
  _BubbleSpec(x: 0.65, size: 16, speed: 1.25, phase: 0.12),
  _BubbleSpec(x: 0.78, size: 22, speed: 1.00, phase: 0.08),
  _BubbleSpec(x: 0.90, size: 10, speed: 1.54, phase: 0.40),
  // Medium
  _BubbleSpec(x: 0.15, size: 9, speed: 1.67, phase: 0.18),
  _BubbleSpec(x: 0.45, size: 11, speed: 1.43, phase: 0.30),
  _BubbleSpec(x: 0.58, size: 8, speed: 1.82, phase: 0.03),
  _BubbleSpec(x: 0.72, size: 13, speed: 1.25, phase: 0.25),
  _BubbleSpec(x: 0.85, size: 7, speed: 1.67, phase: 0.50),
  // Small
  _BubbleSpec(x: 0.30, size: 5, speed: 2.00, phase: 0.10),
  _BubbleSpec(x: 0.48, size: 6, speed: 1.82, phase: 0.45),
  _BubbleSpec(x: 0.82, size: 4, speed: 2.22, phase: 0.22),
];

/// Hero header widget with personalized greeting, key stats,
/// and animated ambient ocean effects (caustic shimmer + rising bubbles).
class HeroHeader extends ConsumerStatefulWidget {
  const HeroHeader({super.key});

  @override
  ConsumerState<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends ConsumerState<HeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _stopwatch = Stopwatch();

  /// Seconds for one conceptual animation cycle (controls bubble rise speed).
  static const _cyclePeriod = 10.0;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    // Controller is used only to schedule repaints every frame.
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
    final diverAsync = ref.watch(dashboardDiverProvider);
    final statsAsync = ref.watch(diveStatisticsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gradient uses icon-harmonious cyan-teal hues instead of theme colors,
    // ensuring the app icon in the corner blends naturally with the banner.
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
    final textColor = isDark ? Colors.white : const Color(0xFF00363D);
    final bubbleColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.22);
    final causticOpacity = isDark ? 0.06 : 0.12;

    return Semantics(
      label: context.l10n.dashboard_semantics_greetingBanner,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Animated ocean effects (caustic shimmer + rising bubbles)
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _ticker,
                    builder: (context, _) {
                      final t =
                          _stopwatch.elapsedMilliseconds /
                          (_cyclePeriod * 1000);
                      return CustomPaint(
                        painter: _OceanEffectPainter(
                          animationValue: t,
                          bubbleColor: bubbleColor,
                          causticOpacity: causticOpacity,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // App icon
              Positioned(
                right: 16,
                top: 8,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    diverAsync.when(
                      data: (diver) {
                        final greeting = _getGreeting(context);
                        final name =
                            diver?.name.split(' ').first ??
                            context.l10n.dashboard_defaultDiverName;
                        return Text(
                          context.l10n.dashboard_greeting_withName(
                            greeting,
                            name,
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                      loading: () => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      error: (_, _) => Text(
                        context.l10n.dashboard_greeting_withoutName(
                          _getGreeting(context),
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Headline stats - responsive based on screen width
                    statsAsync.when(
                      data: (stats) {
                        // On phones (< 600px), only show dive count to save space
                        // On tablets/desktop, show both dives and hours
                        final screenWidth = MediaQuery.sizeOf(context).width;
                        final showHours = screenWidth >= 600;
                        return Text(
                          _buildHeadlineStats(
                            context,
                            stats,
                            showHours: showHours,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: textColor.withValues(alpha: 0.9),
                          ),
                        );
                      },
                      loading: () => Text(
                        context.l10n.dashboard_hero_loading,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                      error: (_, _) => Text(
                        context.l10n.dashboard_hero_error,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.dashboard_greeting_morning;
    if (hour < 17) return context.l10n.dashboard_greeting_afternoon;
    return context.l10n.dashboard_greeting_evening;
  }

  String _buildHeadlineStats(
    BuildContext context,
    DiveStatistics stats, {
    bool showHours = true,
  }) {
    if (stats.totalDives == 0) return context.l10n.dashboard_hero_noDives;

    final parts = <String>[];

    final diveText = stats.totalDives == 1
        ? context.l10n.dashboard_hero_divesLoggedOne
        : context.l10n.dashboard_hero_divesLoggedOther(stats.totalDives);
    parts.add(diveText);

    if (showHours) {
      final hours = stats.totalTimeSeconds / 3600;
      if (hours >= 1) {
        final hoursStr = hours < 10
            ? hours.toStringAsFixed(1)
            : '${hours.round()}';
        parts.add(context.l10n.dashboard_hero_hoursUnderwater(hoursStr));
      } else if (stats.totalTimeSeconds > 0) {
        final minutes = stats.totalTimeSeconds ~/ 60;
        parts.add(context.l10n.dashboard_hero_minutesUnderwater(minutes));
      }
    }

    return parts.join(' \u2022 ');
  }
}

/// Paints caustic light shimmer and rising bubbles in a single paint pass.
class _OceanEffectPainter extends CustomPainter {
  final double animationValue;
  final Color bubbleColor;
  final double causticOpacity;

  _OceanEffectPainter({
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

    for (final spec in _bubbleSpecs) {
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
  bool shouldRepaint(_OceanEffectPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
