import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

const ean32 = GasMix(o2: 32);
const ean50 = GasMix(o2: 50);

/// A 30 m dive on EAN32 with a stage of EAN50, for series tests.
DivePlanState seriesDiveState({
  String id = 'dive-a',
  double depth = 30,
  int bottomMinutes = 25,
  double backPressure = 232,
  Duration? surfaceInterval,
}) {
  return DivePlanState(
    id: id,
    name: 'Reef day',
    gfLow: 40,
    gfHigh: 80,
    surfaceInterval: surfaceInterval,
    tanks: [
      DiveTank(
        id: '$id-back',
        volume: 12,
        startPressure: backPressure,
        gasMix: ean32,
      ),
      DiveTank(
        id: '$id-stage',
        volume: 7,
        startPressure: 200,
        gasMix: ean50,
        role: TankRole.deco,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: '$id-descent',
        fromDepth: 0,
        targetDepth: depth,
        tankId: '$id-back',
        gasMix: ean32,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: '$id-bottom',
        depth: depth,
        durationMinutes: bottomMinutes,
        tankId: '$id-back',
        gasMix: ean32,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 27),
    updatedAt: DateTime(2026, 10, 27),
  );
}

/// Sequential ids for appended dives and their tanks and segments.
String Function() idSequence([String prefix = 'id']) {
  var next = 0;
  return () => '$prefix-${next++}';
}

/// A logged dive of [minutes] starting at [start], for following.
Dive loggedDive(
  String id,
  DateTime start, {
  int minutes = 45,
  int? number,
  String? name,
  bool isPlanned = false,
  List<DiveTank> tanks = const [],
}) {
  return Dive(
    id: id,
    diveNumber: number,
    name: name,
    dateTime: start,
    entryTime: start,
    runtime: Duration(minutes: minutes),
    isPlanned: isPlanned,
    tanks: tanks,
  );
}

/// A followed logged dive that ended at [end], having breathed [otu].
SeriesLoggedDive seriesLoggedDive(
  String id,
  DateTime end, {
  int minutes = 45,
  double otu = 0,
  int? number,
}) {
  return SeriesLoggedDive(
    id: id,
    diveNumber: number,
    start: end.subtract(Duration(minutes: minutes)),
    end: end,
    otu: otu,
  );
}
