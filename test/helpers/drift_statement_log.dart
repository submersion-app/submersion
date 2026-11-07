import 'dart:async';

/// The statements [read] sends, for a database opened with
/// `logStatements: true`. Drift logs through `print`, so a zone catches them.
///
/// One entry per statement, each whole: drift prints a long statement in
/// 300-character pieces, so a piece that does not start a log entry is joined
/// back onto the one before it. Without that, a clause past the first piece
/// (a `FROM` after a long column list) is invisible to the caller. Build
/// fixtures outside [read], or their writes count.
Future<List<String>> statementsOf(Future<void> Function() read) async {
  final logged = <String>[];
  await runZoned(
    read,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => logged.add(line),
    ),
  );
  return joinDriftLogLines(
    logged,
  ).where((line) => line.startsWith('Drift: Sent')).toList();
}

/// [lines] as drift logged them, with each continuation piece of a long
/// entry joined back onto the entry it belongs to.
List<String> joinDriftLogLines(Iterable<String> lines) {
  final entries = <String>[];
  for (final line in lines) {
    if (line.startsWith('Drift: ') || entries.isEmpty) {
      entries.add(line);
    } else {
      entries.last += line;
    }
  }
  return entries;
}

/// Whether [statement] reads a series blob: drift's full row read of either
/// series table, or the blob column by name.
bool readsSeriesBlob(String statement) => RegExp(
  r'SELECT \* FROM "(dive_profile_series|tank_pressure_series)"'
  r'|\bsamples\b',
).hasMatch(statement);
