import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/wall_clock.dart';

/// The one badge a species card shows (issue #5027).
enum SpeciesRarity { newSpecies, seenOnce, notSeenLately, mastered }

/// A species first seen within this long is New.
const kNewSpeciesWindow = Duration(days: 90);

/// A species last seen longer ago than this is Not seen lately.
const kNotSeenLatelyAfter = Duration(days: 730);

/// The practice box that reads as Mastered.
const kMasteredBox = 5;

/// [entry]'s badge: the first that applies of New, Seen once, Not seen
/// lately and Mastered, or null.
SpeciesRarity? rarityFor(
  SeenSpecies entry, {
  required DateTime now,
  int? practiceBox,
}) {
  final today = wallClock(now);
  if (today.difference(wallClock(entry.firstSeen)) <= kNewSpeciesWindow) {
    return SpeciesRarity.newSpecies;
  }
  if (entry.diveCount == 1) return SpeciesRarity.seenOnce;
  if (today.difference(wallClock(entry.lastSeen)) > kNotSeenLatelyAfter) {
    return SpeciesRarity.notSeenLately;
  }
  if (practiceBox != null && practiceBox >= kMasteredBox) {
    return SpeciesRarity.mastered;
  }
  return null;
}
