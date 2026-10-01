/// One tank pressure reading: seconds from dive start and bar.
typedef PressureReading = ({int t, double bar});

/// How far below the level around it a reading must sit to count as a dip,
/// in bar. Readings between two samples of a draining cylinder move by a bar
/// or two at most, so this cannot catch ordinary consumption.
const double kPressureGlitchMinDipBar = 5.0;

/// The longest a dip that does not reach zero may last and still count as a
/// misread, in seconds, measured from the good reading before it to the good
/// reading after it. A lower reading that persists longer is treated as
/// real, since nothing short of a lost signal explains it.
const int kPressureGlitchMaxSeconds = 120;

/// Readings below this, in bar, are what a transmitter that lost its signal
/// logs. Nobody breathes from a cylinder at this pressure, so a run of them
/// between normal readings is a dropout however long it lasts.
const double kPressureGlitchNearZeroBar = 5.0;

/// How far the reading after a dip may sit below the level before it, in bar,
/// covering the gas breathed while the reading was off.
const double kPressureGlitchReturnBelowBar = 10.0;

/// How far the reading after a dip may sit above the level before it, in bar.
/// A dip that returns much higher is no misread of one cylinder. Real
/// logbooks show dips coming back a little over 3 bar higher.
const double kPressureGlitchReturnAboveBar = 5.0;

/// The same allowance after a near-zero dropout, in bar. A dropout can last
/// minutes, over which a cylinder warming in the water gains a few bar, and
/// a reading of ~0 bar is never real whatever follows it.
const double kPressureGlitchDropoutReturnAboveBar = 10.0;

/// How far below the first stable reading a lead-in reading must sit, in bar,
/// to count as taken before the valve was open or the transmitter paired.
const double kPressureGlitchLeadInGapBar = 10.0;

/// Where a tank pressure series holds readings that do not describe the
/// cylinder: signal dropouts, transient misreads and a lead-in logged before
/// the valve was open (issue #2441).
class PressureGlitchScan {
  const PressureGlitchScan({
    required this.glitchIndices,
    required this.episodeCount,
  });

  static const PressureGlitchScan none = PressureGlitchScan(
    glitchIndices: {},
    episodeCount: 0,
  );

  /// Indices into the scanned series of every reading to disregard.
  final Set<int> glitchIndices;

  /// How many separate glitches the series holds: a run of consecutive
  /// glitch readings counts once.
  final int episodeCount;
}

/// Finds the readings of a time-ordered tank pressure series that do not
/// describe the cylinder.
///
/// Three shapes are recognised:
///
/// * a lead-in: readings in the first [kPressureGlitchMaxSeconds] (or of any
///   length, while they stay near zero) that sit more than
///   [kPressureGlitchLeadInGapBar] below the first reading after them;
/// * a near-zero dropout: readings below [kPressureGlitchNearZeroBar] between
///   two normal ones, whatever their length;
/// * a transient dip: readings more than [kPressureGlitchMinDipBar] below
///   both the reading before and the reading after them, lasting at most
///   [kPressureGlitchMaxSeconds], after which the pressure returns to the
///   prior level;
/// * a transient spike: the same above both neighbours.
///
/// A drop with no recovery after it is left alone: nothing in the series
/// shows it to be a misread. The series is not changed.
PressureGlitchScan scanPressureGlitches(List<PressureReading> readings) {
  final n = readings.length;
  if (n < 2) return PressureGlitchScan.none;

  final glitches = <int>{};
  var episodes = 0;

  final leadIn = _leadInLength(readings);
  if (leadIn > 0) {
    glitches.addAll([for (var i = 0; i < leadIn; i++) i]);
    episodes++;
  }

  // The last reading taken as describing the cylinder.
  var previous = leadIn;
  var i = leadIn + 1;
  while (i < n) {
    final level = readings[previous].bar;
    final bar = readings[i].bar;
    final dips = bar < level - kPressureGlitchMinDipBar;
    final spikes = bar > level + kPressureGlitchMinDipBar;
    if (!dips && !spikes) {
      previous = i;
      i++;
      continue;
    }
    final k = spikes
        ? _spikeEnd(readings, i, level)
        : _dipEnd(readings, i, level);
    // No reading after the excursion means nothing shows it was not real;
    // it is taken as the new level like any other change, and the scan goes
    // on.
    final isGlitch =
        k < n &&
        (spikes
            ? _isSpike(readings, previous, i, k)
            : _isGlitch(readings, previous, i, k));
    if (isGlitch) {
      glitches.addAll([for (var j = i; j < k; j++) j]);
      episodes++;
      previous = k;
      i = k + 1;
    } else {
      previous = i;
      i++;
    }
  }

  return PressureGlitchScan(glitchIndices: glitches, episodeCount: episodes);
}

/// [readings] without the readings [scanPressureGlitches] finds, or the same
/// list when it finds none.
List<PressureReading> withoutPressureGlitches(List<PressureReading> readings) =>
    _cleanReadings(readings, scanPressureGlitches(readings));

/// [readings] without the readings [scan] marks, or the same list when it
/// marks none.
List<PressureReading> _cleanReadings(
  List<PressureReading> readings,
  PressureGlitchScan scan,
) {
  if (scan.glitchIndices.isEmpty) return readings;
  return [
    for (var i = 0; i < readings.length; i++)
      if (!scan.glitchIndices.contains(i)) readings[i],
  ];
}

/// The start ([atStart]) or end pressure to record for a cylinder, given what
/// the source reported and the cylinder's pressure series.
///
/// A source that derives its endpoints from the samples (libdivecomputer's
/// Shearwater parser takes the first and last non-zero reading) inherits any
/// glitch sitting at either end. When [reportedBar] matches a glitch reading
/// of [readings] that sits below the first or last clean reading, that clean
/// reading replaces it; any other value, and a null, comes back unchanged.
///
/// Only a low glitch counts: a lead-in, a dropout and a dip all read below
/// the cylinder, and those are what a source takes an endpoint from. A
/// reported value that equals a spike, which reads above it, is a header
/// value that happens to coincide, and is kept.
///
/// [readings] must be in time order. A caller resolving both endpoints of one
/// cylinder passes the [scan] of [readings] it already holds, so the series
/// is scanned once rather than per endpoint.
double? replaceGlitchedEndpoint({
  required double? reportedBar,
  required List<PressureReading> readings,
  required bool atStart,
  PressureGlitchScan? scan,
}) {
  if (reportedBar == null) return null;
  scan ??= scanPressureGlitches(readings);
  if (scan.glitchIndices.isEmpty) return reportedBar;
  final clean = _cleanReadings(readings, scan);
  if (clean.isEmpty) return reportedBar;
  final replacement = atStart ? clean.first.bar : clean.last.bar;
  final matchesLowGlitch = scan.glitchIndices.any(
    (i) =>
        readings[i].bar < replacement &&
        (readings[i].bar - reportedBar).abs() <= _endpointMatchToleranceBar,
  );
  return matchesLowGlitch ? replacement : reportedBar;
}

/// The start ([atStart]) or end pressure to record for a cylinder whose
/// source reported [reportedBar] for that end and [otherBar] for the other.
///
/// A value below [kPressureGlitchNearZeroBar] is what a transmitter that lost
/// its signal logs, and a source can report one as a header pressure even
/// when no reading of its series matches it, which [replaceGlitchedEndpoint]
/// requires (issue #2687). A value that is not finite describes no cylinder
/// either and is treated the same way. Such a value is resolved from
/// [readings]:
///
/// * where the first or last clean reading is itself above that bound, the
///   series contradicts the value and that reading replaces it. A series
///   that drops straight to near zero and stays there until the log ends is
///   a dropout nothing came after, so the reading before the drop counts as
///   its last;
/// * where the clean reading is near zero as well, the series agrees and the
///   value is kept;
/// * where there is no series, the value is cleared to null when [otherBar]
///   is a real pressure, so the cylinder records no end (or start) rather
///   than one nobody breathed down to. With no real pressure at either end
///   there is nothing to judge it against, and it is kept.
///
/// Any other value, and a null, comes back unchanged. [readings] must be in
/// time order; [scan] is the scan of [readings] when the caller holds it.
double? replaceNearZeroEndpoint({
  required double? reportedBar,
  required double? otherBar,
  required List<PressureReading> readings,
  required bool atStart,
  PressureGlitchScan? scan,
}) {
  if (reportedBar == null ||
      (reportedBar.isFinite && reportedBar >= kPressureGlitchNearZeroBar)) {
    return reportedBar;
  }
  if (readings.isNotEmpty) {
    final clean = _cleanReadings(
      readings,
      scan ?? scanPressureGlitches(readings),
    );
    if (clean.isNotEmpty) {
      final seriesBar = atStart ? clean.first.bar : _lastRealBar(clean);
      return seriesBar >= kPressureGlitchNearZeroBar ? seriesBar : reportedBar;
    }
  }
  final otherIsReal =
      otherBar != null && otherBar >= kPressureGlitchNearZeroBar;
  return otherIsReal ? null : reportedBar;
}

/// The last reading of the clean, time-ordered series [clean], or the one
/// before a near-zero run that closes it when that run starts with a drop of
/// more than [kPressureGlitchMinDipBar]. A cylinder drained into near zero
/// reading by reading keeps its last reading: the series shows it emptying.
double _lastRealBar(List<PressureReading> clean) {
  var k = clean.length - 1;
  while (k > 0 && clean[k].bar < kPressureGlitchNearZeroBar) {
    k--;
  }
  final last = clean.last.bar;
  if (k == clean.length - 1) return last;
  final before = clean[k].bar;
  final dropsStraightDown =
      before >= kPressureGlitchNearZeroBar &&
      before - clean[k + 1].bar > kPressureGlitchMinDipBar;
  return dropsStraightDown ? before : last;
}

/// The first and last clean reading of a tank pressure series, in any order,
/// or null when it holds none.
///
/// Used where a cylinder's start and end pressure are derived from its
/// series because the source reported none: a dropout at either end of the
/// series must not become the recorded pressure (issue #2441).
({double start, double end})? cleanSeriesEndpoints(
  List<PressureReading> readings,
) {
  final clean = withoutPressureGlitches(readingsInTimeOrder(readings));
  if (clean.isEmpty) return null;
  return (start: clean.first.bar, end: clean.last.bar);
}

/// [readings] sorted by time, readings sharing a second kept in the order
/// given. Dart's List.sort is not stable, and every glitch rule reads the
/// series in time order.
List<PressureReading> readingsInTimeOrder(List<PressureReading> readings) {
  final indexed = [for (var i = 0; i < readings.length; i++) (i, readings[i])]
    ..sort((a, b) {
      final byTime = a.$2.t.compareTo(b.$2.t);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

// Sources quantize pressure before converting it (Shearwater logs 2 psi
// units), so a reported value and the sample it came from can differ by a
// fraction of a bar.
const double _endpointMatchToleranceBar = 0.5;

/// How many readings at the head of [readings] were logged before the
/// cylinder was connected, or 0.
int _leadInLength(List<PressureReading> readings) {
  var best = 0;
  var allNearZero = true;
  // The highest reading before q: every one of them sits below the ceiling
  // exactly when it does. Kept as a running value so each candidate costs
  // O(1) rather than a rescan of the head, which on a transmitter that
  // never paired (a whole dive near zero, so the window never closes) made
  // the scan quadratic.
  var highestBefore = double.negativeInfinity;
  for (var q = 1; q < readings.length; q++) {
    final previousBar = readings[q - 1].bar;
    allNearZero = allNearZero && previousBar < kPressureGlitchNearZeroBar;
    if (previousBar > highestBefore) highestBefore = previousBar;
    final span = readings[q - 1].t - readings.first.t;
    if (span > kPressureGlitchMaxSeconds && !allNearZero) break;
    if (highestBefore >= readings[q].bar - kPressureGlitchLeadInGapBar) {
      continue;
    }
    // The reading the lead-in ends at must start a stable stretch, or a
    // spike early in the dive would pass for it and take every reading
    // before it along.
    if (!_startsStableStretch(readings, q)) continue;
    best = q;
  }
  return best;
}

/// How many readings after the end of a lead-in must stay near it.
const int _leadInStableReadings = 3;

/// Whether the readings after [q] (up to [_leadInStableReadings] of them)
/// all stay within [kPressureGlitchMinDipBar] of `readings[q]`. A near-zero
/// dropout among them is passed over: it says nothing about the cylinder.
bool _startsStableStretch(List<PressureReading> readings, int q) {
  var checked = 0;
  for (
    var j = q + 1;
    j < readings.length && checked < _leadInStableReadings;
    j++
  ) {
    if (readings[j].bar < kPressureGlitchNearZeroBar) continue;
    if ((readings[j].bar - readings[q].bar).abs() > kPressureGlitchMinDipBar) {
      return false;
    }
    checked++;
  }
  return true;
}

/// The index just past the dip starting at [start] below [level].
///
/// A dropout lasts as long as the reading stays near zero: measuring it
/// against the prior level instead would swallow the first good reading
/// after a long dropout, which by then sits several bar lower from the gas
/// breathed meanwhile. Any other dip ends where the reading climbs back to
/// within [kPressureGlitchMinDipBar] of the level, or jumps up by more than
/// that from the reading before, which is the recovery even when it lands a
/// few bar short of the prior level.
int _dipEnd(List<PressureReading> readings, int start, double level) {
  if (readings[start].bar < kPressureGlitchNearZeroBar) {
    var k = start;
    while (k < readings.length &&
        readings[k].bar < kPressureGlitchNearZeroBar) {
      k++;
    }
    return k;
  }
  var k = start + 1;
  while (k < readings.length &&
      readings[k].bar < level - kPressureGlitchMinDipBar &&
      !_recoversFromDip(readings, k, level)) {
    k++;
  }
  return k;
}

/// Whether `readings[k]` is the recovery from a dip below [level]: a jump
/// up of more than [kPressureGlitchMinDipBar] that lands within reach of the
/// level. A jump that stays well below it is the dip wobbling, not ending.
bool _recoversFromDip(List<PressureReading> readings, int k, double level) =>
    readings[k].bar - readings[k - 1].bar > kPressureGlitchMinDipBar &&
    readings[k].bar >= level - kPressureGlitchReturnBelowBar;

/// The index just past the spike starting at [start] above [level]: where
/// the reading falls back to within [kPressureGlitchMinDipBar] of the level,
/// or drops by more than that from the reading before.
int _spikeEnd(List<PressureReading> readings, int start, double level) {
  var k = start + 1;
  while (k < readings.length &&
      readings[k].bar > level + kPressureGlitchMinDipBar &&
      readings[k - 1].bar - readings[k].bar <= kPressureGlitchMinDipBar) {
    k++;
  }
  return k;
}

/// Whether the spike at `readings[start, end)`, entered from the good
/// reading at [before] and left at `readings[end]`, is a misread: short,
/// well above both neighbours, and followed by the pressure the cylinder
/// held before it. A step up that stays is no misread.
bool _isSpike(List<PressureReading> readings, int before, int start, int end) {
  final level = readings[before].bar;
  final after = readings[end].bar;
  if (after > level + kPressureGlitchReturnAboveBar ||
      after < level - kPressureGlitchReturnBelowBar) {
    return false;
  }
  final ceiling = (after > level ? after : level) + kPressureGlitchMinDipBar;
  for (var j = start; j < end; j++) {
    if (readings[j].bar <= ceiling) return false;
  }
  return readings[end].t - readings[before].t <= kPressureGlitchMaxSeconds;
}

/// Whether the dip at `readings[start, end)`, entered from the good reading
/// at [before] and left at `readings[end]`, is a misread rather than a real
/// change.
bool _isGlitch(List<PressureReading> readings, int before, int start, int end) {
  final level = readings[before].bar;
  final after = readings[end].bar;
  final floor = (after < level ? after : level) - kPressureGlitchMinDipBar;
  var nearZero = true;
  for (var j = start; j < end; j++) {
    final bar = readings[j].bar;
    if (bar >= floor) return false;
    if (bar >= kPressureGlitchNearZeroBar) nearZero = false;
  }
  if (nearZero) {
    return after <= level + kPressureGlitchDropoutReturnAboveBar;
  }
  if (after > level + kPressureGlitchReturnAboveBar) return false;
  // Measured between the good readings either side, not across the dip
  // alone: in a sparsely sampled series the drop may have happened at any
  // point of a long gap, where it is as likely real consumption.
  final span = readings[end].t - readings[before].t;
  return after >= level - kPressureGlitchReturnBelowBar &&
      span <= kPressureGlitchMaxSeconds;
}
