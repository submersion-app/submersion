import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The dive and site entries of a usage map, so the #1849 and #1933
/// expectations written as `(dives: n, sites: m)` hold whatever other scopes
/// the registry gains. The `!` asserts the maps are dense: the repository
/// returns an entry for every scope.
({int dives, int sites}) divesAndSites(Map<TagScope, int> usage) =>
    (dives: usage[TagScope.dives]!, sites: usage[TagScope.sites]!);
