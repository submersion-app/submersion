import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_daylight.dart';
import 'package:submersion/features/trips/domain/services/day_rhythm_layout.dart';
import 'package:submersion/features/trips/presentation/widgets/story/day_rhythm_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One day's dives plotted as blocks on a 24h axis, over a sky that shows
/// night, sunrise, day and sunset at the day's dive site (issue #4375).
/// Night dives are tinted with a light tertiary color; surface intervals
/// appear as gaps. The real sunrise and sunset times are labelled under the
/// bar; a day with no placed site draws the sky at the 06:00 and 18:00
/// stand-ins and shows only hour ticks.
class DayRhythmBar extends StatefulWidget {
  final List<Dive> dives;

  /// Formats the sun times and hour ticks in the diver's time format.
  final UnitFormatter units;

  /// Height of the painted track; the label row sits below it.
  final double trackHeight;

  const DayRhythmBar({
    super.key,
    required this.dives,
    required this.units,
    this.trackHeight = 16,
  });

  @override
  State<DayRhythmBar> createState() => _DayRhythmBarState();
}

class _DayRhythmBarState extends State<DayRhythmBar> {
  // Laying out the blocks and the sky resolves each site's time zone, so it
  // runs when the dives change rather than on every rebuild. The labels are
  // formatted in build, so a changed time format shows at once.
  late List<RhythmBlock> _blocks;
  late DayDaylight _daylight;
  late List<SkyStop> _stops;

  @override
  void initState() {
    super.initState();
    _layOut();
  }

  @override
  void didUpdateWidget(DayRhythmBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.dives, widget.dives)) _layOut();
  }

  void _layOut() {
    _blocks = computeRhythmBlocks(widget.dives);
    _daylight = computeDayDaylight(widget.dives);
    _stops = skyStops(_daylight);
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final palette = isDark ? _SkyPalette.dark : _SkyPalette.light;
    final units = widget.units;
    final sunrise = _daylight.sunrise;
    final sunset = _daylight.sunset;

    String time(DateTime wallClock) => units.formatTime(wallClock);
    RhythmLabel tick(int hour) => (
      kind: RhythmLabelKind.tick,
      centerFraction: hour / 24,
      text: time(DateTime(2000, 1, 1, hour)),
    );
    final labels = <RhythmLabel>[
      if (_daylight.basis == DaylightBasis.fallback) ...[
        tick(6),
        tick(12),
        tick(18),
      ] else ...[
        if (sunrise != null)
          (
            kind: RhythmLabelKind.sunrise,
            centerFraction: sunrise.fraction,
            text: time(sunrise.wallClock),
          ),
        tick(12),
        if (sunset != null)
          (
            kind: RhythmLabelKind.sunset,
            centerFraction: sunset.fraction,
            text: time(sunset.wallClock),
          ),
      ],
    ];

    final l10n = context.l10n;
    final semanticsLabel = switch ((sunrise, sunset)) {
      (final rise?, final set?) =>
        l10n.trips_story_rhythm_semanticsSunriseSunset(
          time(rise.wallClock),
          time(set.wallClock),
        ),
      (final rise?, null) => l10n.trips_story_rhythm_semanticsSunrise(
        time(rise.wallClock),
      ),
      (null, final set?) => l10n.trips_story_rhythm_semanticsSunset(
        time(set.wallClock),
      ),
      (null, null) => l10n.trips_story_rhythm_semantics,
    };

    return Semantics(
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.trackHeight,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RhythmPainter(
                blocks: _blocks,
                stops: _stops,
                palette: palette,
                dayColor: colorScheme.primary,
                nightColor: isDark
                    ? colorScheme.tertiary
                    : Color.lerp(colorScheme.tertiary, Colors.white, 0.45)!,
                outlineColor: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 2),
          DayRhythmLabelRow(
            labels: labels,
            tickStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            sunStyle: TextStyle(color: palette.label),
          ),
        ],
      ),
    );
  }
}

/// The sky's colours. Fixed rather than taken from the theme: they stand for
/// the light outside, which no colour scheme changes. Dark mode is darker and
/// less saturated so the bar does not glare.
class _SkyPalette {
  final Color night;
  final Color sunriseGlow;
  final Color day;
  final Color sunsetGlow;
  final Color label;

  const _SkyPalette({
    required this.night,
    required this.sunriseGlow,
    required this.day,
    required this.sunsetGlow,
    required this.label,
  });

  static const light = _SkyPalette(
    night: Color(0xFF24305A),
    sunriseGlow: Color(0xFFF3A35E),
    day: Color(0xFFDCEAF6),
    sunsetGlow: Color(0xFFEE8A5E),
    label: Color(0xFF8A5A1E),
  );

  static const dark = _SkyPalette(
    night: Color(0xFF0D1222),
    sunriseGlow: Color(0xFFA8622F),
    day: Color(0xFF2F4157),
    sunsetGlow: Color(0xFFA65236),
    label: Color(0xFFE8B871),
  );

  Color of(SkyTone tone) => switch (tone) {
    SkyTone.night => night,
    SkyTone.sunriseGlow => sunriseGlow,
    SkyTone.day => day,
    SkyTone.sunsetGlow => sunsetGlow,
  };
}

class _RhythmPainter extends CustomPainter {
  final List<RhythmBlock> blocks;
  final List<SkyStop> stops;
  final _SkyPalette palette;
  final Color dayColor;
  final Color nightColor;
  final Color outlineColor;

  const _RhythmPainter({
    required this.blocks,
    required this.stops,
    required this.palette,
    required this.dayColor,
    required this.nightColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final track = Offset.zero & size;
    final trackRRect = RRect.fromRectAndRadius(track, const Radius.circular(4));
    canvas
      ..save()
      ..clipRRect(trackRRect);

    // The gradient spans every stop, including those before 00:00 or after
    // 24:00, and the clip cuts it off at the bar's ends.
    final first = stops.first.fraction;
    final span = stops.last.fraction - first;
    final sky = Paint();
    if (span <= 0) {
      sky.color = palette.of(stops.first.tone);
    } else {
      sky.shader =
          LinearGradient(
            colors: [for (final stop in stops) palette.of(stop.tone)],
            stops: [for (final stop in stops) (stop.fraction - first) / span],
          ).createShader(
            Rect.fromLTWH(
              first * size.width,
              0,
              span * size.width,
              size.height,
            ),
          );
    }
    canvas.drawRect(track, sky);

    final blockHeight = (size.height - 4).clamp(0.0, double.infinity);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outlineColor;
    for (final block in blocks) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          block.startFraction * size.width,
          2,
          block.widthFraction * size.width,
          blockHeight,
        ),
        const Radius.circular(3),
      );
      canvas
        ..drawRRect(
          rect,
          Paint()..color = block.isNight ? nightColor : dayColor,
        )
        ..drawRRect(rect, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RhythmPainter oldDelegate) =>
      !listEquals(oldDelegate.blocks, blocks) ||
      !listEquals(oldDelegate.stops, stops) ||
      oldDelegate.palette != palette ||
      oldDelegate.dayColor != dayColor ||
      oldDelegate.nightColor != nightColor ||
      oldDelegate.outlineColor != outlineColor;
}
