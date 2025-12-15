import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// Creates an in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Sets up the test database in DatabaseService
Future<AppDatabase> setUpTestDatabase() async {
  final db = createTestDatabase();
  DatabaseService.instance.setTestDatabase(db);
  return db;
}

/// Tears down the test database
Future<void> tearDownTestDatabase() async {
  final db = DatabaseService.instance.database;
  await db.close();
  DatabaseService.instance.resetForTesting();
}
