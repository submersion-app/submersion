/// Subsurface's built-in tag list, mapped onto Submersion's built-in dive
/// type and site type slugs (issue #2202).
///
/// Subsurface has no dive type field: a cave diver records the cave in the
/// `tags` attribute, from a fixed list the program ships with. Carrying those
/// across as free text alone left every imported dive on 'recreational' or
/// 'technical', so a whole logbook arrived with its identity flattened.
///
/// Matching is exact on the lowercased tag, never a substring: 'cavern'
/// contains 'cave', and a `contains` test in the wrong order turns every
/// cavern dive into a cave dive. Exact matching also keeps a diver's own tag
/// ('cave rescue course') out of the classification, where a substring test
/// would claim it.
///
/// Only Subsurface's own vocabulary is mapped. A tag outside it stays what it
/// already was: a tag.
library;

/// Subsurface tags that say something about the dive. The values are built-in
/// dive type slugs seeded by `kSeedBuiltInDiveTypesSql`.
///
/// 'student' is the tag a Subsurface diver puts on a course dive, so it maps
/// to 'training', matching the CSV pipeline's `parseDiveType`. 'instructor'
/// describes who the diver was rather than what the dive was, and 'fresh',
/// 'photo' and 'video' have no dive type at all: those stay tags.
const Map<String, String> kSubsurfaceTagDiveTypes = {
  'cave': 'cave',
  'cavern': 'cavern',
  'wreck': 'wreck',
  'boat': 'boat',
  'shore': 'shore',
  'drift': 'drift',
  'deep': 'deep',
  'ice': 'ice',
  'altitude': 'altitude',
  'night': 'night',
  'student': 'training',
};

/// Subsurface tags that say something about the place. The values are built-in
/// site type slugs from `kBuiltInSiteTypes`.
///
/// These only ever become suggestions (`suggestedSiteTypeRefs`), because a
/// tag describes one dive: a single cavern dive at a site the diver has
/// already classified must not reclassify it.
const Map<String, String> kSubsurfaceTagSiteTypes = {
  'cave': 'cave',
  'cavern': 'cavern',
  'wreck': 'wreck',
  'pool': 'pool',
  'lake': 'lake',
  'river': 'river',
};

/// The built-in dive type [tag] classifies a dive as, or null.
String? subsurfaceTagDiveType(String tag) =>
    kSubsurfaceTagDiveTypes[_normalize(tag)];

/// The built-in site type [tag] suggests for a dive's site, or null.
String? subsurfaceTagSiteType(String tag) =>
    kSubsurfaceTagSiteTypes[_normalize(tag)];

String _normalize(String tag) => tag.trim().toLowerCase();
