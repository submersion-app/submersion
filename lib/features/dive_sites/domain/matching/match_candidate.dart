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

  const MatchCandidate({
    required this.id,
    required this.location,
    required this.isExisting,
    this.isRegister = false,
  });
}
