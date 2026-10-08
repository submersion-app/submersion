/// An item on both the scanned dive and another profile's dive (issue
/// #2853).
class SharedGearItem {
  const SharedGearItem({
    required this.equipmentId,
    required this.name,
    required this.thisLinkKinds,
    required this.otherLinkKinds,
    this.hostIds = const {},
    this.installedPartIds = const [],
  });

  final String equipmentId;
  final String name;

  /// Every way the item is on each dive: `gearList`, `tankCylinder`,
  /// `tankRegulator`, `transmitter`.
  final Set<String> thisLinkKinds;
  final Set<String> otherLinkKinds;

  /// The item's host (`parent_equipment_id`), its assembly parents and the
  /// `via_equipment_id` of its gear rows on either dive.
  final Set<String> hostIds;

  /// Active items installed in it now, sorted.
  final List<String> installedPartIds;
}

/// Another profile's dive near the scanned one that shares at least one
/// item with it (issue #2853). Times are UTC wall-clock instants.
class SharedGearOverlap {
  const SharedGearOverlap({
    required this.otherDiveId,
    required this.otherDiverId,
    required this.otherDiverName,
    required this.thisDiverName,
    required this.otherEntry,
    required this.otherExit,
    required this.items,
  });

  final String otherDiveId;
  final String otherDiverId;
  final String otherDiverName;
  final String thisDiverName;
  final DateTime otherEntry;

  /// Null when the other dive has no duration to derive an exit from.
  final DateTime? otherExit;
  final List<SharedGearItem> items;
}
