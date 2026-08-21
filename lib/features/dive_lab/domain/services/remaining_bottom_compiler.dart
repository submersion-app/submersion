import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// Samples within this of a level's running mean belong to that level.
const double kLevelToleranceMeters = 1.5;

/// A later sample more than this deeper means the ascent had not begun.
const double kReDescentToleranceMeters = 3.0;

/// Samples at or shallower than this are the safety-stop band, never bottom.
const double kSafetyStopBandMeters = 6.5;

/// Window over which a sample must be level to count as bottom.
const int kLevelWindowSeconds = 60;

/// A depth change faster than this between consecutive samples marks a ramp
/// sample (descending or ascending), never part of a level.
const double kRampRateMetersPerMin = 3.0;

/// The last sample of the bottom phase: the last index that is within
/// [kReDescentToleranceMeters] of the deepest depth still ahead, deeper than
/// [kSafetyStopBandMeters], not sitting on a deco stop (in deco and within
/// 1.5 m of the stop level), and level over the preceding
/// [kLevelWindowSeconds]. Null when nothing qualifies.
int? finalAscentStartIndex({
  required List<double> depths,
  required List<int> timestamps,
  List<int> ndlCurve = const [],
  List<double> decoStopCurve = const [],
}) {
  if (depths.isEmpty || depths.length != timestamps.length) return null;
  final n = depths.length;
  final useStops = ndlCurve.length == n && decoStopCurve.length == n;
  var deepestAhead = 0.0;
  for (var i = n - 1; i >= 0; i--) {
    if (depths[i] > deepestAhead) deepestAhead = depths[i];
    final d = depths[i];
    if (d <= kSafetyStopBandMeters) continue;
    if (d < deepestAhead - kReDescentToleranceMeters) continue;
    if (useStops &&
        ndlCurve[i] < 0 &&
        d <= decoStopCurve[i] + kLevelToleranceMeters) {
      continue;
    }
    if (_isOnRamp(depths, timestamps, i)) continue;
    if (!_isLevel(depths, timestamps, i)) continue;
    return i;
  }
  return null;
}

/// Whether sample [i] moved faster than [kRampRateMetersPerMin] from the
/// sample before it.
bool _isOnRamp(List<double> depths, List<int> timestamps, int i) {
  if (i == 0) return false;
  final dt = timestamps[i] - timestamps[i - 1];
  if (dt <= 0) return false;
  final rate = (depths[i] - depths[i - 1]).abs() / dt * 60.0;
  return rate > kRampRateMetersPerMin;
}

bool _isLevel(List<double> depths, List<int> timestamps, int i) {
  final from = timestamps[i] - kLevelWindowSeconds;
  for (var j = i; j >= 0 && timestamps[j] >= from; j--) {
    if ((depths[j] - depths[i]).abs() > kLevelToleranceMeters) return false;
  }
  return true;
}

class _Level {
  _Level(this.startIndex, double depth)
    : sum = depth,
      count = 1,
      endIndex = startIndex;
  final int startIndex;
  int endIndex;
  double sum;
  int count;
  double get mean => sum / count;
  void add(int index, double depth) {
    endIndex = index;
    sum += depth;
    count++;
  }
}

/// The dive's remaining bottom phase, from [branchIndex] to [bottomEndIndex],
/// as planner segments (see the spec's re-plan pipeline). Always returns at
/// least one segment: a zero-duration hold at the branch depth anchors the
/// engine's computed ascent when nothing remains.
List<PlanSegment> compileRemainingBottom({
  required List<double> depths,
  required List<int> timestamps,
  required int branchIndex,
  required int? bottomEndIndex,
  required TankSchedule schedule,
  String? forcedTankId,
  int shiftSeconds = 0,
  bool ascendNow = false,
  String idPrefix = 'lab-seg',
}) {
  final branchDepth = depths[branchIndex];
  PlanSegment hold() => PlanSegment(
    id: '$idPrefix-0',
    type: SegmentType.bottom,
    startDepth: branchDepth,
    endDepth: branchDepth,
    durationSeconds: 0,
    tankId: _tankIdAt(schedule, timestamps[branchIndex], forcedTankId),
    gasMix: _mixAt(schedule, timestamps[branchIndex], forcedTankId),
    order: 0,
  );
  if (ascendNow || bottomEndIndex == null || bottomEndIndex <= branchIndex) {
    return [hold()];
  }

  // Group the remaining samples into levels (within the tolerance of the
  // running mean). Ramp samples (moving faster than kRampRateMetersPerMin)
  // belong to no level: they become the transition between levels.
  final levels = <_Level>[_Level(branchIndex, depths[branchIndex])];
  var open = true;
  for (var i = branchIndex + 1; i <= bottomEndIndex; i++) {
    if (_isOnRamp(depths, timestamps, i)) {
      open = false;
      continue;
    }
    final current = levels.last;
    if (open && (depths[i] - current.mean).abs() <= kLevelToleranceMeters) {
      current.add(i, depths[i]);
    } else {
      levels.add(_Level(i, depths[i]));
      open = true;
    }
  }

  final segments = <PlanSegment>[];
  var order = 0;
  for (var k = 0; k < levels.length; k++) {
    final level = levels[k];
    final startTs = timestamps[level.startIndex];
    if (k > 0) {
      final prev = levels[k - 1];
      final transitionSeconds = startTs - timestamps[prev.endIndex];
      if (transitionSeconds > 0) {
        final goingDown = level.mean > prev.mean;
        segments.add(
          PlanSegment(
            id: '$idPrefix-$order',
            type: goingDown ? SegmentType.descent : SegmentType.ascent,
            startDepth: prev.mean,
            endDepth: level.mean,
            durationSeconds: transitionSeconds,
            tankId: _tankIdAt(schedule, startTs, forcedTankId),
            gasMix: _mixAt(schedule, startTs, forcedTankId),
            order: order,
          ),
        );
        order++;
      }
    }
    final holdSeconds = timestamps[level.endIndex] - startTs;
    if (holdSeconds > 0) {
      segments.add(
        PlanSegment(
          id: '$idPrefix-$order',
          type: SegmentType.bottom,
          startDepth: level.mean,
          endDepth: level.mean,
          durationSeconds: holdSeconds,
          tankId: _tankIdAt(schedule, startTs, forcedTankId),
          gasMix: _mixAt(schedule, startTs, forcedTankId),
          order: order,
        ),
      );
      order++;
    }
  }

  if (shiftSeconds != 0) {
    var remaining = shiftSeconds;
    for (var k = segments.length - 1; k >= 0 && remaining != 0; k--) {
      final s = segments[k];
      if (s.type != SegmentType.bottom) continue;
      final newDuration = s.durationSeconds + remaining;
      if (newDuration > 0) {
        segments[k] = s.copyWith(durationSeconds: newDuration);
        remaining = 0;
      } else {
        remaining = newDuration; // still negative: carry into earlier bottoms
        segments.removeAt(k);
      }
    }
    // Drop transitions left dangling at the end after trimming.
    while (segments.isNotEmpty && segments.last.type != SegmentType.bottom) {
      segments.removeLast();
    }
  }

  if (segments.isEmpty) return [hold()];
  return [
    for (var k = 0; k < segments.length; k++)
      segments[k].copyWith(id: '$idPrefix-$k', order: k),
  ];
}

String _tankIdAt(TankSchedule schedule, int t, String? forced) =>
    forced ?? schedule.tankIdAt(t) ?? 'lab-no-tank';

GasMix _mixAt(TankSchedule schedule, int t, String? forced) =>
    (forced != null ? schedule.tankById(forced)?.gasMix : null) ??
    schedule.mixAt(t);
