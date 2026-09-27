/// Per-file result line shown on the bulk import summary.
enum ImportFileOutcomeStatus {
  imported,
  parseFailed,
  needsIndividualImport,
  unsupported,
}

class ImportFileOutcome {
  final String fileName;
  final String formatName;
  final ImportFileOutcomeStatus status;
  final int importedDives;
  final String? error;

  /// True when this file was excluded because it is a Seacraft ENC
  /// underwater-route log, not because its dive-log format simply needs
  /// the manual column-mapping wizard. Only this case gets an "Import as
  /// route" action on the summary row: a plain CSV needing the mapping
  /// wizard has no equivalent single-file flow to hand it off to here.
  final bool isNavTrackRoute;

  /// The file's on-disk path, when the batch was picked by path (as
  /// opposed to raw bytes with no path, e.g. some share-sheet intents).
  /// Needed to re-read the file for [isNavTrackRoute]'s "Import as route"
  /// action, since the batch pipeline reads bytes only to detect the
  /// format and does not keep them around afterward.
  final String? filePath;

  const ImportFileOutcome({
    required this.fileName,
    required this.formatName,
    required this.status,
    this.importedDives = 0,
    this.error,
    this.isNavTrackRoute = false,
    this.filePath,
  });
}
