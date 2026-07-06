import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One depth/time variant of the base plan in a range table.
class RangeCell {
  final double depthDelta;
  final int timeDelta;
  final PlanOutcome outcome;

  const RangeCell({
    required this.depthDelta,
    required this.timeDelta,
    required this.outcome,
  });

  bool get isBase => depthDelta == 0 && timeDelta == 0;
}

/// The classic slate matrix: depth variants (rows) x time variants
/// (columns). A null cell means the variant was not computable (it would
/// have taken a segment to zero depth or zero duration).
class RangeTable {
  final List<double> depthDeltas;
  final List<int> timeDeltas;

  /// Row-major: `cells[depthIndex][timeIndex]`.
  final List<List<RangeCell?>> cells;

  const RangeTable({
    required this.depthDeltas,
    required this.timeDeltas,
    required this.cells,
  });

  bool get isEmpty => cells.every((row) => row.every((c) => c == null));

  RangeCell? get baseCell {
    for (final row in cells) {
      for (final cell in row) {
        if (cell != null && cell.isBase) return cell;
      }
    }
    return null;
  }
}

/// Builds range tables by re-running the PlanEngine on deviated plans
/// (same deviation semantics as the contingency trio via [deviatePlan]).
class RangeTableService {
  final PlanEngineConfig config;

  const RangeTableService({this.config = const PlanEngineConfig()});

  static const defaultDepthDeltas = [-6.0, -3.0, 0.0, 3.0, 6.0];
  static const defaultTimeDeltas = [-10, -5, 0, 5, 10];

  RangeTable compute(
    domain.DivePlan plan, {
    List<double> depthDeltas = defaultDepthDeltas,
    List<int> timeDeltas = defaultTimeDeltas,
  }) {
    final engine = PlanEngine(config: config);
    final maxDepth = plan.maxDepth;
    final minBottomMinutes = _shortestBottomMinutes(plan);

    final cells = <List<RangeCell?>>[
      for (final depthDelta in depthDeltas)
        [
          for (final timeDelta in timeDeltas)
            _cell(
              engine,
              plan,
              depthDelta,
              timeDelta,
              maxDepth: maxDepth,
              minBottomMinutes: minBottomMinutes,
            ),
        ],
    ];

    return RangeTable(
      depthDeltas: depthDeltas,
      timeDeltas: timeDeltas,
      cells: cells,
    );
  }

  RangeCell? _cell(
    PlanEngine engine,
    domain.DivePlan plan,
    double depthDelta,
    int timeDelta, {
    required double maxDepth,
    required int? minBottomMinutes,
  }) {
    if (plan.segments.isEmpty) return null;
    // A variant must keep the bottom under water and its duration positive.
    if (maxDepth + depthDelta <= 0) return null;
    if (minBottomMinutes != null && minBottomMinutes + timeDelta <= 0) {
      return null;
    }

    final variant = deviatePlan(
      plan,
      depthDelta: depthDelta,
      timeDeltaMinutes: timeDelta,
    );
    return RangeCell(
      depthDelta: depthDelta,
      timeDelta: timeDelta,
      outcome: engine.compute(variant),
    );
  }

  int? _shortestBottomMinutes(domain.DivePlan plan) {
    int? shortest;
    for (final segment in plan.segments) {
      if (segment.type != SegmentType.bottom) continue;
      final minutes = segment.durationSeconds ~/ 60;
      if (shortest == null || minutes < shortest) shortest = minutes;
    }
    return shortest;
  }
}
