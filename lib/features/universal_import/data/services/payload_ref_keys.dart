import 'package:submersion/features/universal_import/data/models/import_enums.dart';

// Keys through which payload maps reference other payload entities, and the
// entity type each resolves to. Shared by PayloadMerger (namespacing, alias
// rewrite) and PayloadDiverExpander (which items a dive uses), so a new
// reference key is added in one place. A dive's `site` is a nested map with
// its own `uddfId` and is handled by each caller directly.

/// Dive map fields holding one entity reference.
const Map<String, ImportEntityType> diveScalarRefTypes = {
  'siteId': ImportEntityType.sites,
  'tripRef': ImportEntityType.trips,
  'diveCenterRef': ImportEntityType.diveCenters,
  'courseRef': ImportEntityType.courses,
};

/// Dive map fields holding a list of entity references.
const Map<String, ImportEntityType> diveListRefTypes = {
  'equipmentRefs': ImportEntityType.equipment,
  'buddyRefs': ImportEntityType.buddies,
  'diveGuideRefs': ImportEntityType.buddies,
  'tagRefs': ImportEntityType.tags,
};

/// Fields inside a dive's `gearLinks` entries (issue #1487).
const Map<String, ImportEntityType> gearLinkRefTypes = {
  'itemRef': ImportEntityType.equipment,
  'viaRef': ImportEntityType.equipment,
  'setRef': ImportEntityType.equipmentSets,
};

/// Field inside an equipment item's `components` entries (issue #1487).
const Map<String, ImportEntityType> componentRefTypes = {
  'componentRef': ImportEntityType.equipment,
};

/// Site map fields holding a list of entity references (issue #1765). A
/// site's `siteTypeRefs` are slugs into metadata, not entities, so they are
/// not listed.
const Map<String, ImportEntityType> siteListRefTypes = {
  'tagRefs': ImportEntityType.tags,
};

/// Service record field naming the equipment item it belongs to.
const Map<String, ImportEntityType> serviceRecordRefTypes = {
  'equipmentRef': ImportEntityType.equipment,
};

/// Field inside a dive's `buddyRoleRefs` entries (issue #1737).
const Map<String, ImportEntityType> buddyRoleRefTypes = {
  'buddyRef': ImportEntityType.buddies,
};
