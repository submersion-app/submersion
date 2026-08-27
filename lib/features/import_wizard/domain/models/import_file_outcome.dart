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

  const ImportFileOutcome({
    required this.fileName,
    required this.formatName,
    required this.status,
    this.importedDives = 0,
    this.error,
  });
}
