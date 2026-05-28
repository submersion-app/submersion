import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A site the matcher considers for one dive. `id` is an existing site id when
/// [isExisting] is true, otherwise a bundled site's `externalId`.
class MatchCandidate {
  final String id;
  final GeoPoint location;
  final bool isExisting;

  const MatchCandidate({
    required this.id,
    required this.location,
    required this.isExisting,
  });
}
