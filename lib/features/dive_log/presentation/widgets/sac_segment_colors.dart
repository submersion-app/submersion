import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// The colors shared by the time chart and the rows beneath it, so a column
/// and its phase read as the same thing and the rows double as the legend.
///
/// The hues name a phase and say nothing about how it went, so ascent keeps
/// clear of the green, yellow and red a dive computer uses for ascent rate,
/// and no phase wears red. They are drawn at full strength, because mixing
/// them into a light card turns the set into pastels. They were checked for
/// color vision deficiency across the phases that can share an edge, which
/// includes bottom beside a stop when a short ascent wins no column. Descent
/// rarely meets deco, which is what lets those two sit closer than the others.
/// Picking a column also marks its phase row, so nothing depends on color
/// alone.
abstract final class SacSegmentColors {
  static Color forPhase(DivePhase phase, Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (phase) {
      DivePhase.descent => Color(light ? 0xFF0B4FBA : 0xFF166DD9),
      DivePhase.bottom => Color(light ? 0xFF087116 : 0xFF0A7E35),
      DivePhase.ascent => Color(light ? 0xFF0993A7 : 0xFF07A4B4),
      DivePhase.safetyStop => Color(light ? 0xFFED9C11 : 0xFFC38622),
      DivePhase.deco => Color(light ? 0xFF7130BD : 0xFF6C58C8),
    };
  }
}
