/// When a diver breathed a logged cylinder at the surface, as the recording
/// shows it (issue #2930).
///
/// The gas-use window leaves surface runs out of a whole-dive SAC or RMV, but
/// a diver who breathes oxygen on the boat after a deco dive, or swims on the
/// regulator, used gas in those minutes too. A surface minute counts at 1 bar,
/// so putting it back gives the right rate. Pure: SAC by cylinder runs it on
/// the dive's switches and pressure series, and the derived metrics sweep on
/// the same inputs, so both stretch the window the same way.
library;

import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';

/// A cylinder whose pressure moves less than this, in bar, on the surface was
/// not breathed there: above transmitter resolution and the swing of a
/// cylinder warming or cooling as it leaves the water, and under about four
/// minutes of breathing on a 12 L cylinder.
const double kSurfaceBreathingMinDropBar = 5.0;

/// One sample of a cylinder's pressure series.
typedef PressureSample = ({int timestamp, double bar});

/// How far, in the recording's own seconds, a gas-use window stretches over
/// surface time a cylinder was breathed in: back to [from] before the
/// descent, on to [until] after the ascent. Null on a side nothing moves.
class SurfaceBreathing {
  final int? from;
  final int? until;

  const SurfaceBreathing({this.from, this.until});

  @override
  bool operator ==(Object other) =>
      other is SurfaceBreathing && other.from == from && other.until == until;

  @override
  int get hashCode => Object.hash(from, until);

  @override
  String toString() => 'SurfaceBreathing($from, $until)';
}

/// The surface breathing the recording shows around [underwater], the
/// window depth alone gives. Null when nothing says a cylinder was breathed
/// on the surface.
///
/// - [switchTimes]: switches to breathing cylinders. One logged after the
///   window closes means the diver switched on the surface (oxygen on the
///   boat), so the window runs on to [recordingEnd]. Those before it say
///   nothing: the starting gas is always logged in the leading run.
/// - [pressures]: breathing cylinders' series. One that falls at least
///   [kSurfaceBreathingMinDropBar] below its value where the window closes
///   stretches the window to where it is lowest; one that was that much
///   higher before the descent stretches it back to where it last was
///   highest.
SurfaceBreathing? surfaceBreathingOf({
  required GasUseWindow underwater,
  required int recordingStart,
  required int recordingEnd,
  required Iterable<int> switchTimes,
  required Iterable<List<PressureSample>> pressures,
}) {
  int? from;
  int? until;
  void stretchTo(int t) {
    if (t > underwater.endSeconds) {
      until = until == null || t > until! ? t : until;
    } else if (t < underwater.startSeconds) {
      from = from == null || t < from! ? t : from;
    }
  }

  for (final t in switchTimes) {
    if (t > underwater.endSeconds && t <= recordingEnd) stretchTo(recordingEnd);
  }

  for (final series in pressures) {
    // A transmitter that loses its signal logs near-zero or stray readings,
    // which would read as a cylinder emptied on the surface (issue #2441).
    final ordered = [
      for (final r in withoutPressureGlitches(
        readingsInTimeOrder([
          for (final s in series) (t: s.timestamp, bar: s.bar),
        ]),
      ))
        if (r.bar >= kPressureGlitchNearZeroBar) (timestamp: r.t, bar: r.bar),
    ];
    final trailing = _lowestAfter(ordered, underwater.endSeconds);
    if (trailing != null && trailing <= recordingEnd) stretchTo(trailing);
    final leading = _highestBefore(ordered, underwater.startSeconds);
    if (leading != null && leading >= recordingStart) stretchTo(leading);
  }

  if (from == null && until == null) return null;
  return SurfaceBreathing(from: from, until: until);
}

/// When [series] first reaches its lowest after [time], if that is at least
/// [kSurfaceBreathingMinDropBar] below its value at [time].
int? _lowestAfter(List<PressureSample> series, int time) {
  final base = _barAt(series, time);
  if (base == null) return null;
  PressureSample? lowest;
  for (final s in series) {
    if (s.timestamp <= time) continue;
    if (lowest == null || s.bar < lowest.bar) lowest = s;
  }
  if (lowest == null || base - lowest.bar < kSurfaceBreathingMinDropBar) {
    return null;
  }
  return lowest.timestamp;
}

/// When [series] was last at its highest before [time], if that is at least
/// [kSurfaceBreathingMinDropBar] above its value at [time].
int? _highestBefore(List<PressureSample> series, int time) {
  final base = _barAt(series, time);
  if (base == null) return null;
  PressureSample? highest;
  for (final s in series) {
    if (s.timestamp >= time) break;
    if (highest == null || s.bar >= highest.bar) highest = s;
  }
  if (highest == null || highest.bar - base < kSurfaceBreathingMinDropBar) {
    return null;
  }
  return highest.timestamp;
}

/// [series] at [time], linear between its samples. Null outside it.
double? _barAt(List<PressureSample> series, int time) {
  for (var i = 0; i < series.length; i++) {
    final s = series[i];
    if (s.timestamp == time) return s.bar;
    if (s.timestamp > time) {
      if (i == 0) return null;
      final p = series[i - 1];
      final f = (time - p.timestamp) / (s.timestamp - p.timestamp);
      return p.bar + (s.bar - p.bar) * f;
    }
  }
  return null;
}
