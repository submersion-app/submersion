import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';

/// Distraction-free chart view for phones (and anyone who wants it):
/// pushed from the chart's expand button.
class PlanChartFullscreenPage extends StatelessWidget {
  const PlanChartFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Padding(
        padding: EdgeInsets.all(8),
        child: PlanProfileChart(),
      ),
    );
  }
}
