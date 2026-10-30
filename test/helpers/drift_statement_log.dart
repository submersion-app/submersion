import 'dart:async';

/// The statements [read] sends, for a database opened with
/// `logStatements: true`. Drift logs through `print`, so a zone catches them.
///
/// Counts statements rather than log lines: a long argument list reaches the
/// zone as two lines. Build fixtures outside [read], or their writes count.
Future<List<String>> statementsOf(Future<void> Function() read) async {
  final logged = <String>[];
  await runZoned(
    read,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => logged.add(line),
    ),
  );
  return logged.where((line) => line.startsWith('Drift: Sent')).toList();
}

/// Whether [statement] reads a series blob: drift's full row read of either
/// series table, or the blob column by name.
bool readsSeriesBlob(String statement) => RegExp(
  r'SELECT \* FROM "(dive_profile_series|tank_pressure_series)"'
  r'|\bsamples\b',
).hasMatch(statement);
