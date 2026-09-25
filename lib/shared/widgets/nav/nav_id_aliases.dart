/// Nav destination ids that were renamed, mapped to the id that replaced them.
///
/// A stored nav order (`nav_primary_ids`, `nav_rail_ids`) outlives the build
/// that wrote it, and `nav_primary_ids` syncs between devices, so an id can
/// arrive after its destination was renamed. `normalizeNavOrder` reads such
/// an id as its replacement, which keeps the user's slot instead of dropping
/// the id and appending the replacement in canonical order.
///
/// The stored value is never rewritten here; the next save writes the new id.
const Map<String, String> kRenamedNavIds = {
  // The Statistics section became Insights.
  'statistics': 'insights',
};
