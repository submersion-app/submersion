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

/// The name of the source a dive tank was read from, so one recording's tank
/// rows can be told from another's. The source is the tank's computer's when
/// it names one; else the tank's own data source (issue #2716); else the
/// primary source (the null-is-primary rule of `dive_tanks.computer_id`).
/// Two sources that name no computer both read as an imported file, so such
/// a source is named by its file wherever another source reads the same.
/// Null on a dive with fewer than two sources, where there is nothing to
/// tell apart, and for a computer or source none of [sources] is.
String? tankSourceName({
  required String? computerId,
  required String? sourceId,
  required List<DiveDataSource> sources,
  required SourceNameLabels labels,
}) {
  if (sources.length < 2) return null;
  final source = sources
      .where(
        (s) => computerId != null
            ? s.computerId == computerId
            : sourceId != null
            ? s.id == sourceId
            : s.isPrimary,
      )
      .firstOrNull;
  if (source == null) return null;
  final name = resolveSourceName(source, labels);
  final shared = sources.any(
    (s) => s.id != source.id && resolveSourceName(s, labels) == name,
  );
  return shared ? source.sourceFileName ?? name : name;
}

String _typeLabel(DiveDataSource source, SourceNameLabels labels) {
  if (source.computerId != null) return labels.unknownComputer;
  if (source.sourceFileName != null || source.sourceFileFormat != null) {
    return labels.importedFile;
  }
  return labels.manualEntry;
}
