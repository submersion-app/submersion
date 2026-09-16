import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';

/// The Divers step's preselected targets (issue #1893).
///
/// 1. A diver whose name matches a profile's, ignoring case and outer
///    spaces, goes to that profile.
/// 2. Otherwise the diver with the most dives goes to the active profile,
///    unless a name match already claimed it.
/// 3. Every other diver gets a new profile.
/// 4. Records with no diver go to the active profile.
Map<String, DiverTarget> defaultDiverMapping({
  required List<SourceDiver> sourceDivers,
  required List<Diver> profiles,
  required String activeDiverId,
}) {
  String norm(String s) => s.trim().toLowerCase();
  final rows = orderedDiverRows(sourceDivers);
  final mapping = <String, DiverTarget>{};
  final claimed = <String>{};

  for (final row in rows) {
    if (row.isUnowned || norm(row.name).isEmpty) continue;
    for (final profile in profiles) {
      if (norm(profile.name) == norm(row.name)) {
        mapping[row.key] = ExistingDiverTarget(profile.id);
        claimed.add(profile.id);
        break;
      }
    }
  }

  var activeTaken = claimed.contains(activeDiverId);
  for (final row in rows) {
    if (row.isUnowned || mapping.containsKey(row.key)) continue;
    if (!activeTaken) {
      mapping[row.key] = ExistingDiverTarget(activeDiverId);
      activeTaken = true;
    } else {
      mapping[row.key] = NewDiverTarget(row.key);
    }
  }

  for (final row in rows) {
    if (row.isUnowned) mapping[row.key] = ExistingDiverTarget(activeDiverId);
  }
  return mapping;
}
