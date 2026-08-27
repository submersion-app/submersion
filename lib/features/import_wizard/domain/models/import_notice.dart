/// Things worth telling the diver about an import that still succeeded.
///
/// Distinct from a failure: the dives were imported, but some data the diver
/// might expect is not in the file. Reported once per kind with a count, so a
/// batch of twenty files does not produce twenty identical rows.
enum ImportNoticeKind {
  /// No tank pressure in the source, so gas consumption and SAC are
  /// unavailable for the affected dives.
  noTankPressure,
}

/// One grouped notice for the import summary screen.
class ImportNotice {
  /// Which notice this is; drives the localized wording in the summary.
  final ImportNoticeKind kind;

  /// How many imported dives the notice applies to.
  final int affectedDives;

  const ImportNotice({required this.kind, required this.affectedDives});
}
