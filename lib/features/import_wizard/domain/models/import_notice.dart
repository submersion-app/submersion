/// Things worth telling the diver about an import that still succeeded.
///
/// Distinct from a failure: the dives were imported, but something the diver
/// might expect did not come across. Reported once per kind with a count, so a
/// batch of twenty files does not produce twenty identical rows.
///
/// Declared in display order, data loss first: the summary lists notices in
/// this order whatever order the files produced them in.
enum ImportNoticeKind {
  /// Dives in the file could not be read and were left out. [ImportNotice.count]
  /// is the number of skipped dives, which were never imported.
  divesSkipped,

  /// Rows of a CSV file that were not imported because their date could not
  /// be read (issue #1828). [ImportNotice.count] is the number of rows and
  /// [ImportNotice.rowNumbers] lists them.
  unreadableDates,

  /// A MacDive library held dives for several divers, all imported into the
  /// current diver. [ImportNotice.names] lists the divers.
  multipleDivers,

  /// Profile data missing or unreadable, so the affected dives have no depth
  /// profile. [ImportNotice.count] is the number of imported dives affected.
  profileUnreadable,

  /// MacDive stored profiles Submersion cannot decode; its XML export carries
  /// readable ones. [ImportNotice.count] is the number of imported dives
  /// affected.
  macdiveProfileUndecodable,

  /// This platform could not decode the dive computer data, so the affected
  /// dives have no depth profile. [ImportNotice.count] is the number of
  /// imported dives affected.
  profileUndecodableOnPlatform,

  /// No tank pressure in the source, so gas consumption and SAC are
  /// unavailable. [ImportNotice.count] is the number of imported dives
  /// affected.
  noTankPressure,

  /// A downloaded tank carried a transmitter serial with no registry entry,
  /// so size and role came from the default preset rather than the diver's
  /// own cylinder (issue #1365). [ImportNotice.count] is the number of
  /// imported dives affected.
  unknownTransmitter,

  /// Auto-mapped CSV columns left out because another column already fills
  /// the same field. [ImportNotice.names] lists the columns.
  columnsNotImported,

  /// CSV values that could not be converted and were left blank.
  /// [ImportNotice.count] is the number of values.
  valuesNotConverted,

  /// Photo references with no file name, which could not be linked.
  /// [ImportNotice.count] is the number of photos.
  photosSkipped,

  /// A MacDive XML file carries no certifications or equipment service
  /// records, because MacDive leaves both out of its XML export.
  macdiveXmlOmitsCertsAndService,

  /// MacDive logbooks are saved searches, so none were imported.
  /// [ImportNotice.names] lists the logbooks.
  macdiveLogbooksNotImported,

  /// With "Retain source dive numbers" on, an imported dive kept a number
  /// that another dive in the log already uses. The number is kept as the
  /// diver asked rather than silently changed, so the diver is told instead
  /// (issue #1832). [ImportNotice.count] is the number of imported dives
  /// affected. Declared last because adapters append it after the grouped
  /// parser notices.
  diveNumberConflict;

  /// Whether the notice reports dives that did not import. Such a notice is
  /// shown even when the run imported nothing, since the missing dives are
  /// exactly what the diver needs to hear about.
  bool get reportsMissingDives =>
      this == divesSkipped || this == unreadableDates;

  /// Whether [ImportNotice.count] counts imported dives, and so can never
  /// exceed the number of dives the run imported.
  bool get countsImportedDives => switch (this) {
    profileUnreadable ||
    macdiveProfileUndecodable ||
    profileUndecodableOnPlatform ||
    noTankPressure ||
    unknownTransmitter ||
    diveNumberConflict => true,
    divesSkipped ||
    unreadableDates ||
    multipleDivers ||
    columnsNotImported ||
    valuesNotConverted ||
    photosSkipped ||
    macdiveXmlOmitsCertsAndService ||
    macdiveLogbooksNotImported => false,
  };
}

/// One grouped notice for the import summary screen.
class ImportNotice {
  /// Which notice this is; drives the localized wording in the summary.
  final ImportNoticeKind kind;

  /// How many items the notice covers; what an item is depends on [kind].
  final int count;

  /// Names the notice lists, such as divers or logbooks; empty for kinds that
  /// list none.
  final List<String> names;

  /// Spreadsheet rows (header = row 1) the notice is about, in order. Only
  /// [ImportNoticeKind.unreadableDates] fills it in.
  final List<int> rowNumbers;

  const ImportNotice({
    required this.kind,
    required this.count,
    this.names = const [],
    this.rowNumbers = const [],
  });
}
