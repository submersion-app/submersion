/// What one import wrote to one diver profile (issue #1893).
class DiverImportOutcome {
  const DiverImportOutcome({
    required this.diverId,
    required this.name,
    required this.isNew,
    required this.isActive,
    this.diveIds = const [],
  });

  final String diverId;
  final String name;

  /// Whether the import created this profile.
  final bool isNew;

  /// Whether this is the profile the app is showing, the only one whose
  /// dives "View Dives" can open.
  final bool isActive;

  /// Dives the import created in this profile.
  final List<String> diveIds;

  /// This outcome without the dives consolidation folded into others.
  DiverImportOutcome withoutDives(Set<String> removed) => DiverImportOutcome(
    diverId: diverId,
    name: name,
    isNew: isNew,
    isActive: isActive,
    diveIds: [
      for (final id in diveIds)
        if (!removed.contains(id)) id,
    ],
  );
}
