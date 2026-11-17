import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A site the matcher considers for one dive. `id` is an existing site id when
/// [isExisting] is true, otherwise a bundled site's `externalId`.
class MatchCandidate {
  final String id;
  final GeoPoint location;
  final bool isExisting;

  /// Whether this is a catalogue register record (a charted wreck, a reef
  /// deployment) and not a place the catalogue lists as dived. A dive site
  /// close to the dive is preferred to one of these.
  final bool isRegister;

  /// Whether this is a catalogue record gathered by research and not
  /// verified against a survey or a register. It is offered, and never
  /// picked on the diver's behalf.
  final bool isResearched;

  /// Whether this researched record's position was read off a counting
  /// page's map. It is offered from up to `kMapPlacedReachMeters` away and
  /// never stands in the way of an automatic match.
  final bool isMapPlaced;

  const MatchCandidate({
    required this.id,
    required this.location,
    required this.isExisting,
    this.isRegister = false,
    this.isResearched = false,
    this.isMapPlaced = false,
  });
}
