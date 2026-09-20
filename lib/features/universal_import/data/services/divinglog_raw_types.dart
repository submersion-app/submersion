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

/// One cylinder, from the `Tank` table or the `Logbook` cylinder columns.
class DivingLogRawTank {
  final int tankId;
  final double? sizeLiters;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? workingPressureBar;
  final double? o2Percent;
  final double? hePercent;

  /// `DblTank` set means a twinset and [sizeLiters] is per cylinder, so the
  /// imported volume doubles.
  final bool isDouble;

  const DivingLogRawTank({
    required this.tankId,
    this.sizeLiters,
    this.startPressureBar,
    this.endPressureBar,
    this.workingPressureBar,
    this.o2Percent,
    this.hePercent,
    this.isDouble = false,
  });
}

/// One `Logbook` row with its cylinders and decoded samples.
///
/// Field units are the source's, not Submersion's: metres, minutes,
/// degrees Celsius, kilograms, litres, bar. The mapper converts.
class DivingLogRawDive {
  final int id;
  final String? uuid;
  final int? number;
  final String? diveDate;
  final String? entryTime;
  final String? country;
  final String? city;
  final String? place;
  final String? buddy;
  final String? divemaster;
  final String? comments;
  final double? depthMeters;
  final int? diveTimeMinutes;
  final double? airTempCelsius;
  final double? waterTempCelsius;
  final double? weightKg;
  final String? divesuit;
  final String? computer;

  /// Diving Log's visibility code: 1 good, 2 medium, 3 bad. 0 and null mean
  /// unset.
  final int? visibilityCode;
  final String? supplyType;
  final List<DivingLogRawTank> tanks;
  final List<DivingLogRawSample> samples;

  const DivingLogRawDive({
    required this.id,
    this.uuid,
    this.number,
    this.diveDate,
    this.entryTime,
    this.country,
    this.city,
    this.place,
    this.buddy,
    this.divemaster,
    this.comments,
    this.depthMeters,
    this.diveTimeMinutes,
    this.airTempCelsius,
    this.waterTempCelsius,
    this.weightKg,
    this.divesuit,
    this.computer,
    this.visibilityCode,
    this.supplyType,
    this.tanks = const [],
    this.samples = const [],
  });
}

/// Everything read from one Diving Log file.
class DivingLogLogbook {
  final List<DivingLogRawDive> dives;
  final DivingLogCapabilities capabilities;

  /// Human-readable notes about columns this file lacked, recorded once per
  /// import as a diagnostic rather than shown per dive.
  final List<String> missingColumnNotes;

  const DivingLogLogbook({
    required this.dives,
    required this.capabilities,
    this.missingColumnNotes = const [],
  });
}
