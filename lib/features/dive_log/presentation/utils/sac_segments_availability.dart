import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether the Gas consumption by segment card should explain that no tank
/// pressure was recorded during the dive (issue #2505).
///
/// Per-segment SAC needs a pressure reading throughout the dive. A cylinder
/// logged with only a start and an end pressure gives the Cylinders card a
/// whole-dive average, but no breakdown: filling in the readings between them
/// (the profile chart's straight "(est.)" line) would make segment SAC vary
/// with depth only because of that assumption. Without this note the card
/// vanished while its section toggle stayed on.
///
/// True once [analysis] has loaded with no SAC curve, meaning no pressure
/// series reached it, while a cylinder holds a start pressure above its end
/// pressure. False while loading, when there are segments to show, and when a
/// pressure series was recorded but produced no segment, since "only start and
/// end pressures" would then be untrue.
bool sacSegmentsLackRecordedPressure(ProfileAnalysis? analysis, Dive dive) {
  if (analysis == null) return false;
  if (analysis.sacSegments?.isNotEmpty ?? false) return false;
  if (analysis.sacCurve != null) return false;
  return dive.tanks.any((tank) {
    final start = tank.startPressure;
    final end = tank.endPressure;
    return start != null && end != null && start > end;
  });
}
