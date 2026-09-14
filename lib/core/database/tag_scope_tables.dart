/// The tag scope registry (issue #1942): where each scope a tag can apply to
/// keeps its flag and its links.
///
/// One const entry per scope, shared by the migration code (which runs before
/// the typed tables exist, so it can only use names), the tag repository and
/// sync. Registry order is the display order, and `TagScope.values` follows
/// it. A new scope appends its entry to [tagScopeTables] and its member to
/// `TagScope`.
///
/// Deliberately import-free, so the domain `TagScope` can depend on it.
library;

/// Where one tag scope stores its flag and its links.
class TagScopeTable {
  const TagScopeTable({
    required this.scopeColumn,
    required this.junctionTable,
    required this.parentColumn,
    required this.syncEntity,
    this.restampedParentTable,
    this.sweepsOrphanLinks = false,
  });

  /// The `tags` flag column saying the tag is offered in this scope.
  final String scopeColumn;

  /// The junction linking a tag to the items of this scope. It has a
  /// surrogate `id`, [parentColumn], `tag_id`, `created_at` and `hlc`.
  final String junctionTable;

  /// The junction column naming the linked item.
  final String parentColumn;

  /// The sync entity type of the junction rows.
  final String syncEntity;

  /// The parent table a tag merge re-stamps when it relinks one of its rows
  /// (`updated_at` bumped, the row marked pending), or null when the links
  /// are clockless children that never touch their parent (#1769). The name
  /// doubles as the parent's sync entity type, which holds for `dives`.
  /// Narrowing a scope never re-stamps a parent.
  final String? restampedParentTable;

  /// Whether the duplicate-tag repair also deletes this junction's links
  /// whose tag no longer exists. Site links always were (#1849); dive links
  /// in that state are left untouched (v149).
  final bool sweepsOrphanLinks;
}

/// Dive tags. A tag merge has always re-stamped the dives it relinks.
const diveTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_dives',
  junctionTable: 'dive_tags',
  parentColumn: 'dive_id',
  syncEntity: 'diveTags',
  restampedParentTable: 'dives',
);

/// Dive site tags (v217, issue #1765).
const siteTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_sites',
  junctionTable: 'site_tags',
  parentColumn: 'site_id',
  syncEntity: 'siteTags',
  sweepsOrphanLinks: true,
);

/// Equipment tags (v219, issue #1942). A link never re-stamps its item: the
/// links are clockless children of the equipment row (#1769). Like site
/// links, links to a tag that no longer exists are swept by the repair.
const equipmentTagScopeTable = TagScopeTable(
  scopeColumn: 'applies_to_equipment',
  junctionTable: 'equipment_tags',
  parentColumn: 'equipment_id',
  syncEntity: 'equipmentTags',
  sweepsOrphanLinks: true,
);

/// Every scope, in display order.
const List<TagScopeTable> tagScopeTables = [
  diveTagScopeTable,
  siteTagScopeTable,
  equipmentTagScopeTable,
];
