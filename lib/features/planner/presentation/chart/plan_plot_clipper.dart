import 'package:flutter/widgets.dart';

/// Clips the plan chart's layers to its plot while the axes are frozen, so a
/// plan that outgrows them mid-drag stays inside the plot until they refit.
class PlanPlotClipper extends CustomClipper<Rect> {
  const PlanPlotClipper(this.plot);

  final Rect plot;

  @override
  Rect getClip(Size size) => plot;

  @override
  bool shouldReclip(PlanPlotClipper oldClipper) => oldClipper.plot != plot;
}
