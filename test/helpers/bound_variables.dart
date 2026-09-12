import 'dart:async';

import 'package:drift/native.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// The most variables one statement may bind on SQLite builds before 3.32,
/// and the budget the repositories chunk their `IN (...)` lists to. Newer
/// builds allow far more, so a statement over it passes locally and fails
/// only on an older platform SQLite; measure it instead.
const sqliteVariableLimit = 999;

/// An in-memory database that logs every statement, installed as the
/// [DatabaseService] database. Pair with [maxBoundVariables].
AppDatabase setUpLoggingTestDatabase() {
  final db = AppDatabase(NativeDatabase.memory(logStatements: true));
  DatabaseService.instance.setTestDatabase(db);
  return db;
}

/// Runs [body] with statement logging swallowed.
Future<T> quietly<T>(Future<T> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
);

/// Runs [body] on a [setUpLoggingTestDatabase] database and returns the most
/// variables any one statement bound. Counts the commas in drift's
/// "with args [...]" list, so it assumes no bound value contains one (ids do
/// not). A long statement reaches the zone in pieces, so each is rebuilt
/// from its "Drift: Sent" line onward before it is counted.
Future<int> maxBoundVariables(Future<void> Function() body) async {
  var most = 0;
  final statement = StringBuffer();
  void count() {
    final text = statement.toString();
    statement.clear();
    final at = text.lastIndexOf('with args [');
    final end = text.lastIndexOf(']');
    if (at < 0 || end < at) return;
    final args = text.substring(at + 'with args ['.length, end).trim();
    final bound = args.isEmpty ? 0 : ','.allMatches(args).length + 1;
    if (bound > most) most = bound;
  }

  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) {
        if (line.startsWith('Drift: Sent')) count();
        statement.write(line);
      },
    ),
  );
  count();
  return most;
}
