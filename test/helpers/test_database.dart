import 'dart:async';

import 'package:drift/native.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Creates an in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
}

/// Sets up the test database in DatabaseService
Future<AppDatabase> setUpTestDatabase() async {
  final db = createTestDatabase();
  DatabaseService.instance.setTestDatabase(db);
  return db;
}

/// [setUpTestDatabase] with every statement logged through `print`, for a
/// test that counts the statements a read costs. Capture them with a zone
/// whose `print` collects lines starting `Drift: Sent`, and count statements
/// rather than lines: one with a long `IN` list arrives as several lines.
///
/// Seed fixtures under [withoutStatementLog], or every insert and the schema
/// creation land in the test output too.
Future<AppDatabase> setUpStatementLoggingTestDatabase() async {
  final db = AppDatabase(
    NativeDatabase.memory(setup: registerAppSqlFunctions, logStatements: true),
  );
  DatabaseService.instance.setTestDatabase(db);
  return db;
}

/// Runs [body] with drift's statement log swallowed and every other print
/// passed through.
Future<T> withoutStatementLog<T>(Future<T> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (!line.startsWith('Drift: ')) parent.print(zone, line);
    },
  ),
);

/// Tears down the test database
Future<void> tearDownTestDatabase() async {
  final db = DatabaseService.instance.database;
  await db.close();
  DatabaseService.instance.resetForTesting();
}
