import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The key each tag scope's flag rides under on an imported tag map
/// (issues #1765, #1942). Parsers write them and UddfEntityImporter reads
/// them. A missing key means the source said nothing about that scope.
const Map<TagScope, String> importTagScopeKeys = {
  TagScope.dives: 'appliesToDives',
  TagScope.sites: 'appliesToSites',
  TagScope.equipment: 'appliesToEquipment',
};

/// The scopes an imported tag map asks for. A scope the map says nothing
/// about keeps its old default: dives on, the others off, so a file that
/// predates scopes imports dive tags as it always did. A map that turns
/// every scope off is read as a dive tag, since a tag must apply somewhere.
Set<TagScope> importedTagScopes(Map<String, dynamic> data) {
  final scopes = {
    for (final MapEntry(key: scope, value: key) in importTagScopeKeys.entries)
      if (data[key] as bool? ?? scope == TagScope.dives) scope,
  };
  return scopes.isEmpty ? const {TagScope.dives} : scopes;
}
