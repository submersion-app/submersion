import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

/// The dive of [finding] that belongs to a profile other than
/// [activeDiverId], or null when the active diver owns every dive it names.
///
/// Only a shared gear pair spans two profiles (the other pair detectors look
/// for neighbors within one diver's dives), and it records each side's diver
/// in `params['dives']`. The inbox shows such a pair to both profiles but lets
/// each act only on its own dive (issue #3049). Null with no active diver,
/// when the inbox is not scoped to anyone.
String? foreignDiveIdOf(QualityFinding finding, String? activeDiverId) {
  final related = finding.relatedDiveId;
  final dives = finding.params['dives'];
  if (activeDiverId == null || related == null || dives is! Map) return null;
  String? diverOf(String diveId) {
    final side = dives[diveId];
    return side is Map ? side['diverId'] as String? : null;
  }

  final anchorDiver = diverOf(finding.diveId);
  final relatedDiver = diverOf(related);
  if (anchorDiver == activeDiverId && relatedDiver != activeDiverId) {
    return related;
  }
  if (relatedDiver == activeDiverId && anchorDiver != activeDiverId) {
    return finding.diveId;
  }
  return null;
}
