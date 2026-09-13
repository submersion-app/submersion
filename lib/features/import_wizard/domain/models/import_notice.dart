/// Things worth telling the diver about an import that still succeeded.
///
/// Distinct from a failure: the dives were imported, but some data the diver
/// might expect is not in the file. Reported once per kind with a count, so a
/// batch of twenty files does not produce twenty identical rows.
enum ImportNoticeKind {
  /// No tank pressure in the source, so gas consumption and SAC are
  /// unavailable for the affected dives.
  noTankPressure,

  /// A downloaded tank carried a transmitter serial with no registry entry,
  /// so size and role came from the default preset rather than the diver's
  /// own cylinder (issue #1365).
  unknownTransmitter,

  /// With "Retain source dive numbers" on, an imported dive kept a number
  /// that another dive in the log already uses. The number is kept as the
  /// diver asked rather than silently changed, so the diver is told instead
  /// (issue #1832).
  diveNumberConflict,
}

/// One grouped notice for the import summary screen.
class ImportNotice {
  /// Which notice this is; drives the localized wording in the summary.
  final ImportNoticeKind kind;

  /// How many imported dives the notice applies to.
  final int affectedDives;

  const ImportNotice({required this.kind, required this.affectedDives});
}
