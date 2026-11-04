import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_scrub_readout.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';

/// The scrub readout and the bailout status along the top of the plan chart,
/// for its [Stack].
///
/// The bailout status goes top centre: on a phone the corners hold the
/// readouts and the bottom edge holds the chips. In one column with the scrub
/// readout, which reaches past the centre on a narrow chart, so it clears the
/// readout at any text size.
class PlanChartTopReadouts extends StatelessWidget {
  const PlanChartTopReadouts({
    super.key,
    required this.scrubTime,
    required this.series,
    required this.units,
    required this.palette,
  });

  /// The scrub cursor's runtime in seconds, or null when not scrubbing.
  final double? scrubTime;
  final PlanCanvasSeries series;
  final UnitFormatter units;
  final PlanChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final scrubTime = this.scrubTime;
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          if (scrubTime != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: PlanChartGeometry.leftGutter + 4,
                ),
                child: PlanScrubReadout(
                  runtimeSeconds: scrubTime,
                  depthMeters: series.depthAt(scrubTime),
                  units: units,
                  palette: palette,
                ),
              ),
            ),
          const PlanChartBailoutStatus(),
        ],
      ),
    );
  }
}
