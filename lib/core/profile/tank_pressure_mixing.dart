import 'package:submersion/core/profile/tank_pressure_glitches.dart';

/// How far a reading must sit from the only track so far to open a second
/// one, in bar. A single recording moves by a bar or two between samples;
/// two recordings of one cylinder, or of two cylinders, sit further apart.
const double kMixedTrackSplitBar = 5.0;

/// How many readings each track needs before the series counts as mixed.
const int kMixedMinTrackReadings = 5;

/// How often the series must alternate between the two tracks. A dropout or
/// two in one recording switches a handful of times; interleaved recordings
/// switch every few samples (ten times and more in real logbooks).
const int kMixedMinSwitches = 8;

/// How long, in seconds, both tracks must run side by side.
const int kMixedMinOverlapSeconds = 60;

/// How many timestamps must carry two different readings (more than
/// [_duplicateConflictBar] apart) for the series to count as mixed on that
/// evidence alone: one recording never reads twice at the same second.
const int kMixedMinConflictingDuplicates = 3;

const double _duplicateConflictBar = 1.0;

/// Whether a time-ordered tank pressure series holds two recordings
/// interleaved into one (issue #2440).
///
/// Schema v182 packed each tank's legacy rows into one series per computer,
/// and two file imports of one dive, consolidated, both carry no computer:
/// their readings of the same cylinder landed in a single series, shifted
/// against each other by the difference in their clocks. Nothing records
/// which reading came from which source, so such a series can only be
/// recognised by its shape: either several timestamps read twice with
/// different values, or the readings split into two tracks that the series
/// keeps alternating between.
///
/// Near-zero readings are left out of the tracks: a signal dropout is not a
/// second recording ([scanPressureGlitches] handles those). Only meaningful
/// for a dive with more than one data source; a single recording cannot mix
/// with itself, and its glitches would otherwise read as a second track.
bool looksLikeInterleavedSources(List<PressureReading> readings) {
  if (_conflictingDuplicates(readings) >= kMixedMinConflictingDuplicates) {
    return true;
  }

  final a = <PressureReading>[];
  final b = <PressureReading>[];
  List<PressureReading>? previousTrack;
  var switches = 0;
  for (final r in readings) {
    if (r.bar < kPressureGlitchNearZeroBar) continue;
    final List<PressureReading> track;
    if (a.isEmpty) {
      track = a;
    } else if (b.isEmpty) {
      track = (r.bar - a.last.bar).abs() > kMixedTrackSplitBar ? b : a;
    } else {
      track = (r.bar - a.last.bar).abs() <= (r.bar - b.last.bar).abs() ? a : b;
    }
    track.add(r);
    if (previousTrack != null && !identical(track, previousTrack)) {
      switches++;
    }
    previousTrack = track;
  }

  if (a.length < kMixedMinTrackReadings || b.length < kMixedMinTrackReadings) {
    return false;
  }
  final overlapStart = a.first.t > b.first.t ? a.first.t : b.first.t;
  final overlapEnd = a.last.t < b.last.t ? a.last.t : b.last.t;
  return switches >= kMixedMinSwitches &&
      overlapEnd - overlapStart >= kMixedMinOverlapSeconds;
}

/// Near-zero readings are passed over here too: a dropout logged at the
/// second of a real reading is one recording losing its signal.
int _conflictingDuplicates(List<PressureReading> readings) {
  final seen = <int, double>{};
  var conflicts = 0;
  for (final r in readings) {
    if (r.bar < kPressureGlitchNearZeroBar) continue;
    final previous = seen[r.t];
    if (previous != null && (previous - r.bar).abs() > _duplicateConflictBar) {
      conflicts++;
    }
    seen[r.t] = r.bar;
  }
  return conflicts;
}
