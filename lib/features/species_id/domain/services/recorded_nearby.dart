import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';

/// Where to read the "Recorded nearby" list that marks a marine life
/// suggestion (issue #4668): the dive's [site] point, else the [photo]'s
/// own position, else the dive's [entry] point. Null when there is none.
///
/// The site comes first, the other way round from naming's place rule
/// (`mediaLocation`), on purpose: the marker then reads the very list the
/// site page shows under "Recorded nearby", and a dive needs one lookup
/// rather than one per photo position. At the list's 5 km radius the two
/// points rarely differ by much.
GeoPoint? nearbyListLocation({
  GeoPoint? site,
  GeoPoint? photo,
  GeoPoint? entry,
}) => site ?? photo ?? entry;

/// Whether a suggestion is on [nearby]: one of its [gbifKeys] is a species
/// the search returned, or its [catalogId] is a catalogue species the list
/// matched.
///
/// The catalogue id is the fallback for a pack candidate whose key is a
/// synonym of the one GBIF's occurrence search reports: the list matched
/// that species to the catalogue by its own key, so the ids still agree.
bool isRecordedNearby(
  NearbySpecies nearby, {
  Iterable<int> gbifKeys = const [],
  String? catalogId,
}) {
  if (gbifKeys.any(nearby.speciesKeys.contains)) return true;
  if (catalogId == null) return false;
  return nearby.matched.any((m) => m.speciesId == catalogId);
}
