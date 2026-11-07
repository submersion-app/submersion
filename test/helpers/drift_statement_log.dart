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
///
/// Drift's default `debugPrint` prints every match of `.{1,300}`, so an entry
/// breaks after 300 characters and at each newline, and the newline itself
/// is dropped. A piece that follows a full 300-character piece continues it
/// directly; any shorter piece ended at a newline, which is put back so two
/// lines of SQL do not run together. A print from outside drift during the
/// read would be joined too, so keep [lines] to drift's own output.
List<String> joinDriftLogLines(Iterable<String> lines) {
  const pieceLength = 300;
  final entries = <String>[];
  var lastPieceLength = 0;
  for (final line in lines) {
    if (line.startsWith('Drift: ') || entries.isEmpty) {
      entries.add(line);
    } else {
      entries.last += lastPieceLength == pieceLength ? line : '\n$line';
    }
    lastPieceLength = line.length;
  }
  return entries;
}

/// Whether [statement] reads a series blob: drift's full row read of either
/// series table, or the blob column by name.
bool readsSeriesBlob(String statement) => RegExp(
  r'SELECT \* FROM "(dive_profile_series|tank_pressure_series)"'
  r'|\bsamples\b',
).hasMatch(statement);
