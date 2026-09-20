/// Which tables and columns a particular Diving Log file actually has.
///
/// Diving Log 5.0, Diving Log 6.0 and DiveLogDT have drifted apart, so
/// every query is narrowed to columns this reports. A missing table skips
/// one entity, a missing column reads as null, and neither aborts the
/// import.
class DivingLogCapabilities {
  final Set<String> tables;
  final Map<String, Set<String>> columns;

  const DivingLogCapabilities({required this.tables, required this.columns});

  bool hasTable(String table) => tables.contains(table);

  bool hasColumn(String table, String column) =>
      columns[table]?.contains(column) ?? false;

  /// The subset of [wanted] that this file actually has, in the given
  /// order, so a SELECT can be built from it directly.
  List<String> availableColumns(String table, List<String> wanted) => [
    for (final c in wanted)
      if (hasColumn(table, c)) c,
  ];

  /// The subset of [wanted] this file lacks, for the diagnostic warning.
  List<String> missingColumns(String table, List<String> wanted) => [
    for (final c in wanted)
      if (!hasColumn(table, c)) c,
  ];
}

/// One decoded profile sample. Every field beyond time and depth is
/// optional because the five packed columns are independently present.
class DivingLogRawSample {
  final int timeSeconds;
  final double depthMeters;
  final bool inDeco;
  final bool ascentWarning;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankId;
  final int? rbtSeconds;
  final int? heartRate;
  final int? ndlSeconds;
  final int? ttsSeconds;
  final double? stopDepthMeters;
  final double? ppO2Cell1;
  final double? ppO2Cell2;
  final double? ppO2Cell3;
  final double? otu;
  final double? cns;
  final double? setpoint;

  const DivingLogRawSample({
    required this.timeSeconds,
    required this.depthMeters,
    this.inDeco = false,
    this.ascentWarning = false,
    this.temperatureCelsius,
    this.pressureBar,
    this.tankId,
    this.rbtSeconds,
    this.heartRate,
    this.ndlSeconds,
    this.ttsSeconds,
    this.stopDepthMeters,
    this.ppO2Cell1,
    this.ppO2Cell2,
    this.ppO2Cell3,
    this.otu,
    this.cns,
    this.setpoint,
  });
}
