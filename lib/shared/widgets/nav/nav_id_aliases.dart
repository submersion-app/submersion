/// Nav destination ids that were renamed, mapped to the id that replaced them.
///
/// A stored nav order (`nav_primary_ids`, `nav_rail_ids`) outlives the build
/// that wrote it, so an id can still be there after its destination was
/// renamed. (The orders stay on each device since issue #2947; before that
/// `nav_primary_ids` synced, which is how many of these ids arrived.)
/// `normalizeNavOrder` reads such an id as its replacement, which keeps the
/// user's slot instead of dropping the id and appending the replacement in
/// canonical order.
///
/// The stored value is never rewritten here; the next save writes the new id,
/// followed by the old one (see [withLegacyNavIds]).
const Map<String, String> kRenamedNavIds = {
  // The Statistics section became Insights.
  'statistics': 'insights',
  // GPS Log became Tracks, which also holds underwater tracks (#2833).
  'gps-log': 'tracks',
};

/// [ids] as they should be saved: each renamed destination's old id written
/// right after its new one.
///
/// A build from before the rename that reads this order (this device after a
/// downgrade; the orders no longer sync, issue #2947) knows only the old id.
/// It drops the new id as unknown and finds the old one in the very next
/// position, so it keeps the user's slot too. This build reads the old id as
/// the new one and drops it as a duplicate, so the extra entry costs nothing
/// here.
///
/// Drop an entry from [kRenamedNavIds] (and with it this extra write) once no
/// supported build predates that rename.
List<String> withLegacyNavIds(List<String> ids) {
  final legacyFor = {
    for (final entry in kRenamedNavIds.entries) entry.value: entry.key,
  };
  return List.unmodifiable([
    for (final id in ids) ...[id, ?legacyFor[id]],
  ]);
}
