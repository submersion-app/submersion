/// Typed import progress phases for the unified import wizard.
///
/// Each value maps to a localized string displayed in the
/// [ImportProgressStep] widget during import.
enum ImportPhase {
  dives,
  sites,
  trips,
  equipment,
  equipmentSets,
  buddies,
  diveCenters,
  certifications,
  tags,
  diveTypes,
  courses,
  applyingTags,
}

/// Callback for reporting import progress.
///
/// [phase] identifies the current entity type being processed.
/// [current] and [total] track item-level progress within that phase.
typedef ImportProgressCallback =
    void Function(ImportPhase phase, int current, int total);
