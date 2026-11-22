import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';

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

  /// [startState] is the live plan's seeded tissues (a repetitive dive's
  /// residual loading); every cell starts from it, as the live plan does.
  RangeTable compute(
    domain.DivePlan plan, {
    List<double> depthDeltas = defaultDepthDeltas,
    List<int> timeDeltas = defaultTimeDeltas,
    TissueState? startState,
  }) {
    final engine = PlanEngine(config: config);
    final maxDepth = plan.maxDepth;
    final descentRate = config.resolvedFor(plan).descentRate;

    final cells = <List<RangeCell?>>[
      for (final depthDelta in depthDeltas)
        _row(
          engine,
          plan,
          depthDelta,
          timeDeltas,
          maxDepth: maxDepth,
          descentRate: descentRate,
          startState: startState,
        ),
    ];

    return RangeTable(
      depthDeltas: depthDeltas,
      timeDeltas: timeDeltas,
      cells: cells,
    );
  }

  /// One depth row. The shortest bottom is measured on the row's own
  /// depth: a deeper rate-split descent spends longer travelling, so it has
  /// less hold left to shrink than the base plan does.
  List<RangeCell?> _row(
    PlanEngine engine,
    domain.DivePlan plan,
    double depthDelta,
    List<int> timeDeltas, {
    required double maxDepth,
    required double descentRate,
    required TissueState? startState,
  }) {
    final minBottomMinutes = _shortestBottomMinutes(
      depthDelta == 0
          ? plan
          : deviatePlan(plan, depthDelta: depthDelta, descentRate: descentRate),
      descentRate,
    );
    return [
      for (final timeDelta in timeDeltas)
        _cell(
          engine,
          plan,
          depthDelta,
          timeDelta,
          maxDepth: maxDepth,
          minBottomMinutes: minBottomMinutes,
          descentRate: descentRate,
          startState: startState,
        ),
    ];
  }

  RangeCell? _cell(
    PlanEngine engine,
    domain.DivePlan plan,
    double depthDelta,
    int timeDelta, {
    required double maxDepth,
    required int? minBottomMinutes,
    required double descentRate,
    required TissueState? startState,
  }) {
    if (plan.segments.isEmpty) return null;
    // A variant must keep the bottom under water and its duration positive.
    if (maxDepth + depthDelta <= 0) return null;
    if (timeDelta != 0) {
      // With no bottom to vary, deviatePlan would leave the time unchanged
      // and the cell would repeat the base value as if the time cost nothing.
      if (minBottomMinutes == null) return null;
      if (minBottomMinutes + timeDelta <= 0) return null;
    }

    final variant = deviatePlan(
      plan,
      depthDelta: depthDelta,
      timeDeltaMinutes: timeDelta,
      descentRate: descentRate,
    );
    return RangeCell(
      depthDelta: depthDelta,
      timeDelta: timeDelta,
      outcome: engine.compute(variant, startState: startState),
    );
  }

  /// Bottom time the table cannot shrink below, or null if the diver has
  /// authored no leg that holds at depth (see [SegmentChain.bottomLegIndex]).
  ///
  /// For a rate-split descent that is only the hold after its travel at the
  /// plan's resolved [descentRate] (#4849): the travel is not bottom time,
  /// and a delta that eats into it would leave a variant with no bottom.
  int? _shortestBottomMinutes(domain.DivePlan plan, double descentRate) {
    final ordered = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    const chain = SegmentChain();
    final legs = chain.resolve(ordered);
    final bottomIndex = chain.bottomLegIndex(legs, descentRate: descentRate);
    if (bottomIndex == null) return null;
    final bottom = legs[bottomIndex];
    if (!bottom.isDepthChange) return bottom.durationSeconds ~/ 60;
    final travelSeconds = PlanSegment.travelSeconds(
      metres: bottom.endDepth - bottom.startDepth,
      ratePerMinute: descentRate,
    );
    final holdSeconds = bottom.durationSeconds - travelSeconds;
    return holdSeconds <= 0 ? 0 : holdSeconds ~/ 60;
  }
}
