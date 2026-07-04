import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// Localized fallback labels for [resolveSourceName]. Built from l10n at the
/// widget layer so the resolver stays a pure domain function.
class SourceNameLabels {
  const SourceNameLabels({
    required this.unknownComputer,
    required this.manualEntry,
    required this.importedFile,
    required this.editedSuffix,
  });

  final String unknownComputer;
  final String manualEntry;
  final String importedFile;

  /// Appended verbatim to the resolved name for a user-edited profile.
  /// Carries its own leading spacing so locales with full-width
  /// punctuation (e.g. zh) can omit the space.
  final String editedSuffix;
}

/// The single name-resolution path for a dive data source, shared by the
/// stat chips, chart legend, sources bar, and data sources section:
/// friendly name -> model -> serial -> source-type label, with
/// "Unknown Computer" reserved for downloads carrying no identifying data.
String resolveSourceName(
  DiveDataSource source,
  SourceNameLabels labels, {
  bool edited = false,
}) {
  final base =
      source.computerName ??
      source.computerModel ??
      source.computerSerial ??
      _typeLabel(source, labels);
  return edited ? '$base${labels.editedSuffix}' : base;
}

String _typeLabel(DiveDataSource source, SourceNameLabels labels) {
  if (source.computerId != null) return labels.unknownComputer;
  if (source.sourceFileName != null || source.sourceFileFormat != null) {
    return labels.importedFile;
  }
  return labels.manualEntry;
}
