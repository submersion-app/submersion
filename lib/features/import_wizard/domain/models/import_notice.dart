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

  /// Rows of a CSV file that were not imported because their date could not
  /// be read (issue #1828). Unlike the others this is about dives missing
  /// from the import, not data missing from dives that imported.
  unreadableDates,
}

/// One grouped notice for the import summary screen.
class ImportNotice {
  /// Which notice this is; drives the localized wording in the summary.
  final ImportNoticeKind kind;

  /// How many imported dives the notice applies to. For
  /// [ImportNoticeKind.unreadableDates], how many rows were not imported.
  final int affectedDives;

  /// Spreadsheet rows (header = row 1) the notice is about, in order. Only
  /// [ImportNoticeKind.unreadableDates] fills it in.
  final List<int> rowNumbers;

  const ImportNotice({
    required this.kind,
    required this.affectedDives,
    this.rowNumbers = const [],
  });
}
