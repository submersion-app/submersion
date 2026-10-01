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

/// The name of the source a dive tank was read from, so one computer's tank
/// rows can be told from another's. A tank with no computer belongs to the
/// primary source (the null-is-primary rule of `dive_tanks.computer_id`).
/// Null on a dive with fewer than two sources, where there is nothing to
/// tell apart, and for a computer none of [sources] carries.
String? tankSourceName({
  required String? computerId,
  required List<DiveDataSource> sources,
  required SourceNameLabels labels,
}) {
  if (sources.length < 2) return null;
  final source = sources
      .where(
        (s) => computerId == null ? s.isPrimary : s.computerId == computerId,
      )
      .firstOrNull;
  return source == null ? null : resolveSourceName(source, labels);
}

String _typeLabel(DiveDataSource source, SourceNameLabels labels) {
  if (source.computerId != null) return labels.unknownComputer;
  if (source.sourceFileName != null || source.sourceFileFormat != null) {
    return labels.importedFile;
  }
  return labels.manualEntry;
}
