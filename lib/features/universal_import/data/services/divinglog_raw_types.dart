/// Quotes [name] as a SQL identifier, doubling any embedded quote.
///
/// Table and column names here come out of a file someone else wrote, so
/// interpolating them raw lets a crafted name change the statement.
String quoteSqlIdentifier(String name) => '"${name.replaceAll('"', '""')}"';

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

  /// This file's spelling of [table], or null when it has no such table.
  ///
  /// Matching ignores case on purpose. The real DiveLogDT export writes
  /// `Tanksize` where we say `TankSize`, and an exact-case miss drops the
  /// column from the SELECT silently: every dive keeps its cylinder but
  /// loses its volume, and with it gas consumption and SAC. That is the
  /// same silent-loss failure this importer exists to fix, so the lookup
  /// resolves the file's own spelling rather than assuming ours.
  String? actualTable(String table) {
    final wanted = table.toLowerCase();
    for (final t in tables) {
      if (t.toLowerCase() == wanted) return t;
    }
    return null;
  }

  /// This file's spelling of [column] in [table], or null when absent.
  String? actualColumn(String table, String column) {
    final t = actualTable(table);
    if (t == null) return null;
    final wanted = column.toLowerCase();
    for (final c in columns[t] ?? const <String>{}) {
      if (c.toLowerCase() == wanted) return c;
    }
    return null;
  }

  bool hasTable(String table) => actualTable(table) != null;

  bool hasColumn(String table, String column) =>
      actualColumn(table, column) != null;

  /// A SELECT column list that aliases each of [wanted] the file has from
  /// its own spelling to ours, so row lookups use our canonical names.
  /// Returns an empty string when none are present.
  String selectList(String table, List<String> wanted) {
    final parts = <String>[];
    for (final c in wanted) {
      final actual = actualColumn(table, c);
      if (actual != null) {
        parts.add('${quoteSqlIdentifier(actual)} AS ${quoteSqlIdentifier(c)}');
      }
    }
    return parts.join(', ');
  }

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
  final double? diveTimeMinutes;
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

  /// Human-readable notes about tables and columns this file lacked,
  /// recorded once per import as diagnostics rather than shown per dive.
  final List<String> schemaNotes;

  const DivingLogLogbook({
    required this.dives,
    required this.capabilities,
    this.schemaNotes = const [],
  });
}
