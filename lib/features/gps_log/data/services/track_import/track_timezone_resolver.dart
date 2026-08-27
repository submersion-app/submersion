import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Real UTC offsets range from -12:00 to +14:00.
const int _kMinOffsetMinutes = -720;
const int _kMaxOffsetMinutes = 840;

/// Converts a real-UTC instant into the app's wall-clock-as-UTC epoch
/// seconds, using an EXPLICIT offset.
///
/// Deliberately distinct from `toWallClockEpochSeconds` in
/// track_point_codec.dart, which uses the running device's local zone. That
/// is correct while recording (the device IS the recorder) and wrong on
/// import (the device is wherever the diver happens to be sitting). Import a
/// Cozumel track in Seattle with the recording-time helper and every fix
/// lands two hours off, silently matching zero dives.
int toWallClockEpochSecondsAt(DateTime realUtc, int tzOffsetMinutes) {
  return realUtc
          .add(Duration(minutes: tzOffsetMinutes))
          .millisecondsSinceEpoch ~/
      1000;
}

/// Inclusive range of offsets, in minutes, that a dive permits.
typedef OffsetRange = ({int lo, int hi});

/// Offsets consistent with [dive] having happened somewhere inside the
/// track's real span, or null when no offset in the real-world range is.
///
/// A dive's stored entry is wall-clock-as-UTC: `W = R + Z`, where R is the
/// real instant and Z the offset. We know W but NOT R, so a single dive
/// cannot determine Z - it only constrains it, because R must lie inside the
/// track:
///
///   `U_first <= W - Z <= U_last`  =>  `W - U_last <= Z <= W - U_first`
///
/// An earlier version returned `W - U_first` directly. That is Z plus the
/// elapsed time from the first fix to the dive entry, so every imported point
/// was shifted by the length of the boat ride - and on a two-tank day the
/// nearest-dive search, running in the same conflated space, preferred the
/// dive whose gap cancelled the offset entirely.
OffsetRange? offsetRangeForDive(
  Dive dive,
  DateTime firstFixUtc,
  DateTime lastFixUtc,
) {
  final w = dive.effectiveEntryTime;
  final lo = w.difference(lastFixUtc).inMinutes;
  final hi = w.difference(firstFixUtc).inMinutes;

  final clampedLo = lo < _kMinOffsetMinutes ? _kMinOffsetMinutes : lo;
  final clampedHi = hi > _kMaxOffsetMinutes ? _kMaxOffsetMinutes : hi;
  if (clampedLo > clampedHi) return null;
  return (lo: clampedLo, hi: clampedHi);
}

int _snapToQuarterHour(int minutes) => (minutes / 15).round() * 15;

/// Best offset for a track, given the dives already logged.
///
/// Returns null when no dive constrains the answer, in which case the caller
/// falls back to the device zone and the import review step asks.
///
/// Where a dive does constrain it, [deviceOffsetMinutes] is used as the prior:
/// if it is already consistent with the track it is kept, otherwise it is
/// pulled to the nearest offset that IS consistent. That is the least
/// surprising correction - it only moves the answer when the device zone is
/// demonstrably impossible for this track.
int? resolveOffsetFromDives({
  required DateTime firstFixUtc,
  required DateTime lastFixUtc,
  required List<Dive> dives,
  required int deviceOffsetMinutes,
}) {
  final ranges = <OffsetRange>[
    for (final dive in dives)
      ?offsetRangeForDive(dive, firstFixUtc, lastFixUtc),
  ];
  if (ranges.isEmpty) return null;

  // The device zone is plausible for this track: keep it.
  for (final r in ranges) {
    if (deviceOffsetMinutes >= r.lo && deviceOffsetMinutes <= r.hi) {
      return deviceOffsetMinutes;
    }
  }

  // Otherwise pull to the nearest consistent offset.
  int? best;
  var bestDistance = 1 << 30;
  for (final r in ranges) {
    final clamped = deviceOffsetMinutes < r.lo ? r.lo : r.hi;
    final distance = (clamped - deviceOffsetMinutes).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      best = clamped;
    }
  }
  if (best == null) return null;

  // Snap to a quarter hour, but stay inside the range that produced it.
  final snapped = _snapToQuarterHour(best);
  for (final r in ranges) {
    if (snapped >= r.lo && snapped <= r.hi) return snapped;
  }
  return best;
}
