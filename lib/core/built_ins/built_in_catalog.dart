/// The catalogs whose built-in entries a diver can hide from the pickers
/// (issue #401). Tank presets predate this and keep their own column.
enum BuiltInCatalog {
  diveTypes('diveTypes'),
  diveRoles('diveRoles'),
  siteTypes('siteTypes'),
  serviceKinds('serviceKinds'),
  preDiveTemplates('preDiveTemplates');

  const BuiltInCatalog(this.key);

  /// The key this catalog is stored under in
  /// `diver_settings.hidden_built_in_ids`. Synced rows carry it, so it must
  /// never be renamed.
  final String key;
}

/// [current] with [id] hidden or shown in [catalog]. Other catalogs, including
/// keys this version does not know, are carried over unchanged, and a catalog
/// left with no hidden ids is dropped. Returns [current] itself when nothing
/// changes.
Map<String, Set<String>> withBuiltInHidden(
  Map<String, Set<String>> current,
  BuiltInCatalog catalog,
  String id,
  bool hidden,
) {
  final ids = current[catalog.key] ?? const <String>{};
  if (ids.contains(id) == hidden) return current;
  final next = hidden
      ? {...ids, id}
      : {
          for (final x in ids)
            if (x != id) x,
        };
  return {
    for (final entry in current.entries)
      if (entry.key != catalog.key) entry.key: entry.value,
    if (next.isNotEmpty) catalog.key: next,
  };
}
