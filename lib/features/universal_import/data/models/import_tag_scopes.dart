import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The key each tag scope's flag rides under on an imported tag map
/// (issues #1765, #1942, #1970). Parsers write them and UddfEntityImporter
/// reads them. A missing key means the source said nothing about that scope.
const Map<TagScope, String> importTagScopeKeys = {
  TagScope.dives: 'appliesToDives',
  TagScope.sites: 'appliesToSites',
  TagScope.equipment: 'appliesToEquipment',
  TagScope.media: 'appliesToMedia',
  TagScope.documents: 'appliesToDocuments',
};

/// Set true on a tag map whose scope flags say only what an existing tag of
/// the same name is widened to, not what a new one is limited to: a new tag
/// is offered everywhere (issue #4407). The equipment CSV sets it.
const importTagNewEverywhereKey = 'newTagEverywhere';

/// Whether the tag map [data] states any scope flag at all.
bool importTagStatesScopes(Map<String, dynamic> data) =>
    importTagScopeKeys.values.any((k) => data[k] != null);

/// The scopes a tag created from [data] gets (issue #4407). A map that
/// states scopes (a Submersion backup) keeps them exactly; one that states
/// none (another app's file, or a backup that predates scopes), or that
/// sets [importTagNewEverywhereKey], is offered everywhere, as any new tag
/// is.
Set<TagScope> importedNewTagScopes(Map<String, dynamic> data) {
  if (!importTagStatesScopes(data) || data[importTagNewEverywhereKey] == true) {
    return TagScope.everywhere;
  }
  return importedTagScopes(data);
}

/// The scopes an imported tag map asks for, which an existing tag of the
/// same name is widened to. A scope the map says nothing
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
